/* valaccodegenerator.vala
 *
 * Copyright (C) 2006-2008  Jürg Billeter, Raffaele Sandrini
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.

 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.

 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
 * Author:
 * 	Jürg Billeter <j@bitron.ch>
 *	Raffaele Sandrini <raffaele@sandrini.ch>
 */

using GLib;
using Gee;

/**
 * Code visitor generating C Code.
 */
public class Vala.CCodeGenerator : CodeGenerator {
	public CCodeModule head;

	public CodeContext context;
	
	public Symbol root_symbol;
	public Symbol current_symbol;
	public TypeSymbol current_type_symbol;
	public Class current_class;
	public Method current_method;
	public DataType current_return_type;
	public TryStatement current_try;
	public PropertyAccessor current_property_accessor;

	public CCodeFragment header_begin;
	public CCodeFragment header_type_declaration;
	public CCodeFragment header_type_definition;
	public CCodeFragment header_type_member_declaration;
	public CCodeFragment header_constant_declaration;
	public CCodeFragment source_begin;
	public CCodeFragment source_include_directives;
	public CCodeFragment source_type_declaration;
	public CCodeFragment source_type_definition;
	public CCodeFragment source_type_member_declaration;
	public CCodeFragment source_constant_declaration;
	public CCodeFragment source_signal_marshaller_declaration;
	public CCodeFragment source_type_member_definition;
	public CCodeFragment class_init_fragment;
	public CCodeFragment instance_init_fragment;
	public CCodeFragment instance_finalize_fragment;
	public CCodeFragment source_signal_marshaller_definition;
	public CCodeFragment module_init_fragment;
	
	public CCodeStruct param_spec_struct;
	public CCodeStruct instance_struct;
	public CCodeStruct type_struct;
	public CCodeStruct instance_priv_struct;
	public CCodeEnum prop_enum;
	public CCodeEnum cenum;
	public CCodeFunction function;
	public CCodeBlock block;
	
	/* all temporary variables */
	public ArrayList<LocalVariable> temp_vars = new ArrayList<LocalVariable> ();
	/* temporary variables that own their content */
	public ArrayList<LocalVariable> temp_ref_vars = new ArrayList<LocalVariable> ();
	/* cache to check whether a certain marshaller has been created yet */
	public Gee.Set<string> user_marshal_set;
	/* (constant) hash table with all predefined marshallers */
	public Gee.Set<string> predefined_marshal_set;
	/* (constant) hash table with all C keywords */
	public Gee.Set<string> c_keywords;
	
	public int next_temp_var_id = 0;
	private int current_try_id = 0;
	private int next_try_id = 0;
	private int next_array_dup_id = 0;
	public bool in_creation_method = false;
	private bool in_constructor = false;
	public bool in_static_or_class_ctor = false;
	public bool current_method_inner_error = false;
	int next_coroutine_state = 1;

	public DataType bool_type;
	public DataType char_type;
	public DataType uchar_type;
	public DataType unichar_type;
	public DataType short_type;
	public DataType ushort_type;
	public DataType int_type;
	public DataType uint_type;
	public DataType long_type;
	public DataType ulong_type;
	public DataType int8_type;
	public DataType uint8_type;
	public DataType int32_type;
	public DataType uint32_type;
	public DataType int64_type;
	public DataType uint64_type;
	public DataType string_type;
	public DataType float_type;
	public DataType double_type;
	public TypeSymbol gtype_type;
	public TypeSymbol gobject_type;
	public ErrorType gerror_type;
	public Class glist_type;
	public Class gslist_type;
	public TypeSymbol gstringbuilder_type;
	public TypeSymbol garray_type;
	public DataType gquark_type;
	public Struct mutex_type;
	public TypeSymbol type_module_type;
	public Interface iterable_type;
	public Interface iterator_type;
	public Interface collection_type;
	public Interface list_type;
	public Interface map_type;
	public TypeSymbol dbus_object_type;

	public Method substring_method;

	public bool in_plugin = false;
	public string module_init_param_name;
	
	public bool string_h_needed;
	public bool gvaluecollector_h_needed;
	public bool gio_h_needed;
	public bool requires_free_checked;
	public bool requires_array_free;
	public bool requires_array_move;
	public bool requires_strcmp0;
	public bool dbus_glib_h_needed;

	public Set<string> wrappers;

	public CCodeGenerator () {
		head = new CCodeBaseModule (this, head);
		head = new CCodeStructModule (this, head);
		head = new CCodeMethodModule (this, head);
		head = new CCodeMemberAccessModule (this, head);
		head = new CCodeAssignmentModule (this, head);
		head = new CCodeInvocationExpressionModule (this, head);
		head = new CCodeArrayModule (this, head);
		head = new CCodeDynamicPropertyModule (this, head);
		head = new CCodeDynamicSignalModule (this, head);
		head = new GObjectModule (this, head);
		head = new GObjectClassModule (this, head);
		head = new GObjectInterfaceModule (this, head);
		head = new GObjectSignalModule (this, head);
		head = new DBusClientModule (this, head);
		head = new DBusServerModule (this, head);

		predefined_marshal_set = new HashSet<string> (str_hash, str_equal);
		predefined_marshal_set.add ("VOID:VOID");
		predefined_marshal_set.add ("VOID:BOOLEAN");
		predefined_marshal_set.add ("VOID:CHAR");
		predefined_marshal_set.add ("VOID:UCHAR");
		predefined_marshal_set.add ("VOID:INT");
		predefined_marshal_set.add ("VOID:UINT");
		predefined_marshal_set.add ("VOID:LONG");
		predefined_marshal_set.add ("VOID:ULONG");
		predefined_marshal_set.add ("VOID:ENUM");
		predefined_marshal_set.add ("VOID:FLAGS");
		predefined_marshal_set.add ("VOID:FLOAT");
		predefined_marshal_set.add ("VOID:DOUBLE");
		predefined_marshal_set.add ("VOID:STRING");
		predefined_marshal_set.add ("VOID:POINTER");
		predefined_marshal_set.add ("VOID:OBJECT");
		predefined_marshal_set.add ("STRING:OBJECT,POINTER");
		predefined_marshal_set.add ("VOID:UINT,POINTER");
		predefined_marshal_set.add ("BOOLEAN:FLAGS");

		c_keywords = new HashSet<string> (str_hash, str_equal);

		// C99 keywords
		c_keywords.add ("_Bool");
		c_keywords.add ("_Complex");
		c_keywords.add ("_Imaginary");
		c_keywords.add ("auto");
		c_keywords.add ("break");
		c_keywords.add ("case");
		c_keywords.add ("char");
		c_keywords.add ("const");
		c_keywords.add ("continue");
		c_keywords.add ("default");
		c_keywords.add ("do");
		c_keywords.add ("double");
		c_keywords.add ("else");
		c_keywords.add ("enum");
		c_keywords.add ("extern");
		c_keywords.add ("float");
		c_keywords.add ("for");
		c_keywords.add ("goto");
		c_keywords.add ("if");
		c_keywords.add ("inline");
		c_keywords.add ("int");
		c_keywords.add ("long");
		c_keywords.add ("register");
		c_keywords.add ("restrict");
		c_keywords.add ("return");
		c_keywords.add ("short");
		c_keywords.add ("signed");
		c_keywords.add ("sizeof");
		c_keywords.add ("static");
		c_keywords.add ("struct");
		c_keywords.add ("switch");
		c_keywords.add ("typedef");
		c_keywords.add ("union");
		c_keywords.add ("unsigned");
		c_keywords.add ("void");
		c_keywords.add ("volatile");
		c_keywords.add ("while");

		// MSVC keywords
		c_keywords.add ("cdecl");
	}

	public override void emit (CodeContext context) {
		this.head.emit (context);

		this.context = context;
	
		context.find_header_cycles ();

		root_symbol = context.root;

		bool_type = new ValueType ((TypeSymbol) root_symbol.scope.lookup ("bool"));
		char_type = new ValueType ((TypeSymbol) root_symbol.scope.lookup ("char"));
		uchar_type = new ValueType ((TypeSymbol) root_symbol.scope.lookup ("uchar"));
		unichar_type = new ValueType ((TypeSymbol) root_symbol.scope.lookup ("unichar"));
		short_type = new ValueType ((TypeSymbol) root_symbol.scope.lookup ("short"));
		ushort_type = new ValueType ((TypeSymbol) root_symbol.scope.lookup ("ushort"));
		int_type = new ValueType ((TypeSymbol) root_symbol.scope.lookup ("int"));
		uint_type = new ValueType ((TypeSymbol) root_symbol.scope.lookup ("uint"));
		long_type = new ValueType ((TypeSymbol) root_symbol.scope.lookup ("long"));
		ulong_type = new ValueType ((TypeSymbol) root_symbol.scope.lookup ("ulong"));
		int8_type = new ValueType ((TypeSymbol) root_symbol.scope.lookup ("int8"));
		uint8_type = new ValueType ((TypeSymbol) root_symbol.scope.lookup ("uint8"));
		int32_type = new ValueType ((TypeSymbol) root_symbol.scope.lookup ("int32"));
		uint32_type = new ValueType ((TypeSymbol) root_symbol.scope.lookup ("uint32"));
		int64_type = new ValueType ((TypeSymbol) root_symbol.scope.lookup ("int64"));
		uint64_type = new ValueType ((TypeSymbol) root_symbol.scope.lookup ("uint64"));
		float_type = new ValueType ((TypeSymbol) root_symbol.scope.lookup ("float"));
		double_type = new ValueType ((TypeSymbol) root_symbol.scope.lookup ("double"));
		string_type = new ObjectType ((Class) root_symbol.scope.lookup ("string"));
		substring_method = (Method) string_type.data_type.scope.lookup ("substring");

		var glib_ns = root_symbol.scope.lookup ("GLib");

		gtype_type = (TypeSymbol) glib_ns.scope.lookup ("Type");
		gobject_type = (TypeSymbol) glib_ns.scope.lookup ("Object");
		gerror_type = new ErrorType (null, null);
		glist_type = (Class) glib_ns.scope.lookup ("List");
		gslist_type = (Class) glib_ns.scope.lookup ("SList");
		gstringbuilder_type = (TypeSymbol) glib_ns.scope.lookup ("StringBuilder");
		garray_type = (TypeSymbol) glib_ns.scope.lookup ("Array");

		gquark_type = new ValueType ((TypeSymbol) glib_ns.scope.lookup ("Quark"));
		mutex_type = (Struct) glib_ns.scope.lookup ("StaticRecMutex");
		
		type_module_type = (TypeSymbol) glib_ns.scope.lookup ("TypeModule");

		if (context.module_init_method != null) {
			module_init_fragment = new CCodeFragment ();
			foreach (FormalParameter parameter in context.module_init_method.get_parameters ()) {
				if (parameter.parameter_type.data_type == type_module_type) {
					in_plugin = true;
					module_init_param_name = parameter.name;
					break;
				}
			}
		}

		var gee_ns = root_symbol.scope.lookup ("Gee");
		if (gee_ns != null) {
			iterable_type = (Interface) gee_ns.scope.lookup ("Iterable");
			iterator_type = (Interface) gee_ns.scope.lookup ("Iterator");
			collection_type = (Interface) gee_ns.scope.lookup ("Collection");
			list_type = (Interface) gee_ns.scope.lookup ("List");
			map_type = (Interface) gee_ns.scope.lookup ("Map");
		}

		var dbus_ns = root_symbol.scope.lookup ("DBus");
		if (dbus_ns != null) {
			dbus_object_type = (TypeSymbol) dbus_ns.scope.lookup ("Object");
		}
	
		/* we're only interested in non-pkg source files */
		var source_files = context.get_source_files ();
		foreach (SourceFile file in source_files) {
			if (!file.external_package) {
				file.accept (this);
			}
		}
	}

	public override void visit_source_file (SourceFile source_file) {
		head.visit_source_file (source_file);
	}

	public override void visit_class (Class cl) {
		head.visit_class (cl);
	}

	public override void visit_interface (Interface iface) {
		head.visit_interface (iface);
	}

	public override void visit_struct (Struct st) {
		head.visit_struct (st);
	}

	public override void visit_enum (Enum en) {
		cenum = new CCodeEnum (en.get_cname ());

		CCodeFragment decl_frag;
		CCodeFragment def_frag;
		if (en.access != SymbolAccessibility.PRIVATE) {
			decl_frag = header_type_declaration;
			def_frag = header_type_definition;
		} else {
			decl_frag = source_type_declaration;
			def_frag = source_type_definition;
		}
		
		if (en.source_reference.comment != null) {
			def_frag.append (new CCodeComment (en.source_reference.comment));
		}

		def_frag.append (cenum);
		def_frag.append (new CCodeNewline ());

		en.accept_children (this);

		if (!en.has_type_id) {
			return;
		}

		decl_frag.append (new CCodeNewline ());

		var macro = "(%s_get_type ())".printf (en.get_lower_case_cname (null));
		decl_frag.append (new CCodeMacroReplacement (en.get_type_id (), macro));

		var clist = new CCodeInitializerList (); /* or during visit time? */
		CCodeInitializerList clist_ev = null;
		foreach (EnumValue ev in en.get_values ()) {
			clist_ev = new CCodeInitializerList ();
			clist_ev.append (new CCodeConstant (ev.get_cname ()));
			clist_ev.append (new CCodeIdentifier ("\"%s\"".printf (ev.get_cname ())));
			clist_ev.append (ev.get_canonical_cconstant ());
			clist.append (clist_ev);
		}

		clist_ev = new CCodeInitializerList ();
		clist_ev.append (new CCodeConstant ("0"));
		clist_ev.append (new CCodeConstant ("NULL"));
		clist_ev.append (new CCodeConstant ("NULL"));
		clist.append (clist_ev);

		var enum_decl = new CCodeVariableDeclarator.with_initializer ("values[]", clist);

		CCodeDeclaration cdecl = null;
		if (en.is_flags) {
			cdecl = new CCodeDeclaration ("const GFlagsValue");
		} else {
			cdecl = new CCodeDeclaration ("const GEnumValue");
		}

		cdecl.add_declarator (enum_decl);
		cdecl.modifiers = CCodeModifiers.STATIC;

		var type_init = new CCodeBlock ();

		type_init.add_statement (cdecl);

		var fun_name = "%s_get_type".printf (en.get_lower_case_cname (null));
		var regfun = new CCodeFunction (fun_name, "GType");
		var regblock = new CCodeBlock ();

		cdecl = new CCodeDeclaration ("GType");
		string type_id_name = "%s_type_id".printf (en.get_lower_case_cname (null));
		cdecl.add_declarator (new CCodeVariableDeclarator.with_initializer (type_id_name, new CCodeConstant ("0")));
		cdecl.modifiers = CCodeModifiers.STATIC;
		regblock.add_statement (cdecl);

		CCodeFunctionCall reg_call;
		if (en.is_flags) {
			reg_call = new CCodeFunctionCall (new CCodeIdentifier ("g_flags_register_static"));
		} else {
			reg_call = new CCodeFunctionCall (new CCodeIdentifier ("g_enum_register_static"));
		}

		reg_call.add_argument (new CCodeConstant ("\"%s\"".printf (en.get_cname())));
		reg_call.add_argument (new CCodeIdentifier ("values"));

		type_init.add_statement (new CCodeExpressionStatement (new CCodeAssignment (new CCodeIdentifier (type_id_name), reg_call)));

		var cond = new CCodeFunctionCall (new CCodeIdentifier ("G_UNLIKELY"));
		cond.add_argument (new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, new CCodeIdentifier (type_id_name), new CCodeConstant ("0")));
		var cif = new CCodeIfStatement (cond, type_init);
		regblock.add_statement (cif);

		regblock.add_statement (new CCodeReturnStatement (new CCodeConstant (type_id_name)));

		if (en.access != SymbolAccessibility.PRIVATE) {
			header_type_member_declaration.append (regfun.copy ());
		} else {
			source_type_member_declaration.append (regfun.copy ());
		}
		regfun.block = regblock;

		source_type_member_definition.append (new CCodeNewline ());
		source_type_member_definition.append (regfun);
	}

	public override void visit_enum_value (EnumValue ev) {
		if (ev.value == null) {
			cenum.add_value (new CCodeEnumValue (ev.get_cname ()));
		} else {
			ev.value.accept (this);
			cenum.add_value (new CCodeEnumValue (ev.get_cname (), (CCodeExpression) ev.value.ccodenode));
		}
	}

	public override void visit_error_domain (ErrorDomain edomain) {
		cenum = new CCodeEnum (edomain.get_cname ());

		if (edomain.source_reference.comment != null) {
			header_type_definition.append (new CCodeComment (edomain.source_reference.comment));
		}
		header_type_definition.append (cenum);

		edomain.accept_children (this);

		string quark_fun_name = edomain.get_lower_case_cprefix () + "quark";

		var error_domain_define = new CCodeMacroReplacement (edomain.get_upper_case_cname (), quark_fun_name + " ()");
		header_type_definition.append (error_domain_define);

		var cquark_fun = new CCodeFunction (quark_fun_name, gquark_type.data_type.get_cname ());
		var cquark_block = new CCodeBlock ();

		var cquark_call = new CCodeFunctionCall (new CCodeIdentifier ("g_quark_from_static_string"));
		cquark_call.add_argument (new CCodeConstant ("\"" + edomain.get_lower_case_cname () + "-quark\""));

		cquark_block.add_statement (new CCodeReturnStatement (cquark_call));

		header_type_member_declaration.append (cquark_fun.copy ());

		cquark_fun.block = cquark_block;
		source_type_member_definition.append (cquark_fun);
	}

	public override void visit_error_code (ErrorCode ecode) {
		if (ecode.value == null) {
			cenum.add_value (new CCodeEnumValue (ecode.get_cname ()));
		} else {
			ecode.value.accept (this);
			cenum.add_value (new CCodeEnumValue (ecode.get_cname (), (CCodeExpression) ecode.value.ccodenode));
		}
	}

	public override void visit_delegate (Delegate d) {
		d.accept_children (this);

		var cfundecl = new CCodeFunctionDeclarator (d.get_cname ());
		foreach (FormalParameter param in d.get_parameters ()) {
			cfundecl.add_parameter ((CCodeFormalParameter) param.ccodenode);

			// handle array parameters
			if (!param.no_array_length && param.parameter_type is ArrayType) {
				var array_type = (ArrayType) param.parameter_type;
				
				var length_ctype = "int";
				if (param.direction != ParameterDirection.IN) {
					length_ctype = "int*";
				}
				
				for (int dim = 1; dim <= array_type.rank; dim++) {
					var cparam = new CCodeFormalParameter (head.get_array_length_cname (param.name, dim), length_ctype);
					cfundecl.add_parameter (cparam);
				}
			}
		}
		if (d.has_target) {
			var cparam = new CCodeFormalParameter ("user_data", "void*");
			cfundecl.add_parameter (cparam);
		}

		var ctypedef = new CCodeTypeDefinition (d.return_type.get_cname (), cfundecl);

		if (!d.is_internal_symbol ()) {
			header_type_declaration.append (ctypedef);
		} else {
			source_type_declaration.append (ctypedef);
		}
	}
	
	public override void visit_member (Member m) {
		/* stuff meant for all lockable members */
		if (m is Lockable && ((Lockable)m).get_lock_used ()) {
			CCodeExpression l = new CCodeIdentifier ("self");
			l = new CCodeMemberAccess.pointer (new CCodeMemberAccess.pointer (l, "priv"), get_symbol_lock_name (m));	

			instance_priv_struct.add_field (mutex_type.get_cname (), get_symbol_lock_name (m));

			var initf = new CCodeFunctionCall (
				new CCodeIdentifier (mutex_type.default_construction_method.get_cname ()));

			initf.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, l));		

			instance_init_fragment.append (new CCodeExpressionStatement (initf));
		
			requires_free_checked = true;


			var fc = new CCodeFunctionCall (new CCodeIdentifier ("g_static_rec_mutex_free"));

			fc.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, l));

			if (instance_finalize_fragment != null) {
				instance_finalize_fragment.append (new CCodeExpressionStatement (fc));
			}
		}
	}

	public override void visit_constant (Constant c) {
		c.accept_children (this);

		if (!(c.type_reference is ArrayType)) {
			var cdefine = new CCodeMacroReplacement.with_expression (c.get_cname (), (CCodeExpression) c.initializer.ccodenode);
			if (!c.is_internal_symbol ()) {
				header_type_member_declaration.append (cdefine);
			} else {
				source_type_member_declaration.append (cdefine);
			}
		} else {
			var cdecl = new CCodeDeclaration (c.type_reference.get_const_cname ());
			var arr = "";
			if (c.type_reference is ArrayType) {
				arr = "[]";
			}
			cdecl.add_declarator (new CCodeVariableDeclarator.with_initializer ("%s%s".printf (c.get_cname (), arr), (CCodeExpression) c.initializer.ccodenode));
			cdecl.modifiers = CCodeModifiers.STATIC;
		
			if (!c.is_internal_symbol ()) {
				header_constant_declaration.append (cdecl);
			} else {
				source_constant_declaration.append (cdecl);
			}
		}
	}

	public override void visit_field (Field f) {
		f.accept_children (this);

		var cl = f.parent_symbol as Class;
		bool is_gtypeinstance = (cl != null && !cl.is_compact);

		CCodeExpression lhs = null;
		CCodeStruct st = null;
		
		string field_ctype = f.field_type.get_cname ();
		if (f.is_volatile) {
			field_ctype = "volatile " + field_ctype;
		}

		if (f.access != SymbolAccessibility.PRIVATE) {
			if (f.binding == MemberBinding.INSTANCE) {
				st = instance_struct;

				lhs = new CCodeMemberAccess.pointer (new CCodeIdentifier ("self"), f.get_cname ());
			} else if (f.binding == MemberBinding.CLASS) {
				st = type_struct;
			} else {
				var cdecl = new CCodeDeclaration (field_ctype);
				cdecl.add_declarator (new CCodeVariableDeclarator (f.get_cname ()));
				cdecl.modifiers = CCodeModifiers.EXTERN;
				header_type_member_declaration.append (cdecl);

				var var_decl = new CCodeVariableDeclarator (f.get_cname ());
				var_decl.initializer = default_value_for_type (f.field_type, true);

				if (f.initializer != null) {
					var init = (CCodeExpression) f.initializer.ccodenode;
					if (is_constant_ccode_expression (init)) {
						var_decl.initializer = init;
					}
				}

				var var_def = new CCodeDeclaration (field_ctype);
				var_def.add_declarator (var_decl);
				var_def.modifiers = CCodeModifiers.EXTERN;
				source_type_member_declaration.append (var_def);

				lhs = new CCodeIdentifier (f.get_cname ());
			}
		} else if (f.access == SymbolAccessibility.PRIVATE) {
			if (f.binding == MemberBinding.INSTANCE) {
				if (is_gtypeinstance) {
					st = instance_priv_struct;
					lhs = new CCodeMemberAccess.pointer (new CCodeMemberAccess.pointer (new CCodeIdentifier ("self"), "priv"), f.get_cname ());
				} else {
					st = instance_struct;
					lhs = new CCodeMemberAccess.pointer (new CCodeIdentifier ("self"), f.get_cname ());
				}
			} else if (f.binding == MemberBinding.CLASS) {
				st = type_struct;
			} else {
				var cdecl = new CCodeDeclaration (field_ctype);
				var var_decl = new CCodeVariableDeclarator (f.get_cname ());
				if (f.initializer != null) {
					var init = (CCodeExpression) f.initializer.ccodenode;
					if (is_constant_ccode_expression (init)) {
						var_decl.initializer = init;
					}
				}
				cdecl.add_declarator (var_decl);
				cdecl.modifiers = CCodeModifiers.STATIC;
				source_type_member_declaration.append (cdecl);

				lhs = new CCodeIdentifier (f.get_cname ());
			}
		}

		if (f.binding == MemberBinding.INSTANCE)  {
			st.add_field (field_ctype, f.get_cname ());
			if (f.field_type is ArrayType && !f.no_array_length) {
				// create fields to store array dimensions
				var array_type = (ArrayType) f.field_type;
				
				for (int dim = 1; dim <= array_type.rank; dim++) {
					var len_type = int_type.copy ();

					st.add_field (len_type.get_cname (), head.get_array_length_cname (f.name, dim));
				}
			} else if (f.field_type is DelegateType) {
				var delegate_type = (DelegateType) f.field_type;
				if (delegate_type.delegate_symbol.has_target) {
					// create field to store delegate target
					st.add_field ("gpointer", get_delegate_target_cname (f.name));
				}
			}

			if (f.initializer != null) {
				var rhs = (CCodeExpression) f.initializer.ccodenode;

				instance_init_fragment.append (new CCodeExpressionStatement (new CCodeAssignment (lhs, rhs)));

				if (f.field_type is ArrayType && !f.no_array_length &&
				    f.initializer is ArrayCreationExpression) {
					var array_type = (ArrayType) f.field_type;
					var this_access = new MemberAccess.simple ("this");
					this_access.value_type = get_data_type_for_symbol ((TypeSymbol) f.parent_symbol);
					this_access.ccodenode = new CCodeIdentifier ("self");
					var ma = new MemberAccess (this_access, f.name);
					ma.symbol_reference = f;
					
					Gee.List<Expression> sizes = ((ArrayCreationExpression) f.initializer).get_sizes ();
					for (int dim = 1; dim <= array_type.rank; dim++) {
						var array_len_lhs = head.get_array_length_cexpression (ma, dim);
						var size = sizes[dim - 1];
						instance_init_fragment.append (new CCodeExpressionStatement (new CCodeAssignment (array_len_lhs, (CCodeExpression) size.ccodenode)));
					}
				}
			}
			
			if (requires_destroy (f.field_type) && instance_finalize_fragment != null) {
				var this_access = new MemberAccess.simple ("this");
				this_access.value_type = get_data_type_for_symbol ((TypeSymbol) f.parent_symbol);
				this_access.ccodenode = new CCodeIdentifier ("self");
				var ma = new MemberAccess (this_access, f.name);
				ma.symbol_reference = f;
				instance_finalize_fragment.append (new CCodeExpressionStatement (get_unref_expression (lhs, f.field_type, ma)));
			}
		} else if (f.binding == MemberBinding.CLASS)  {
			st.add_field (field_ctype, f.get_cname ());
		} else {
			/* add array length fields where necessary */
			if (f.field_type is ArrayType && !f.no_array_length) {
				var array_type = (ArrayType) f.field_type;

				for (int dim = 1; dim <= array_type.rank; dim++) {
					var len_type = int_type.copy ();

					var cdecl = new CCodeDeclaration (len_type.get_cname ());
					cdecl.add_declarator (new CCodeVariableDeclarator (head.get_array_length_cname (f.get_cname (), dim)));
					if (f.access != SymbolAccessibility.PRIVATE) {
						cdecl.modifiers = CCodeModifiers.EXTERN;
						header_type_member_declaration.append (cdecl);
					} else {
						cdecl.modifiers = CCodeModifiers.STATIC;
						source_type_member_declaration.append (cdecl);
					}
				}
			} else if (f.field_type is DelegateType) {
				var delegate_type = (DelegateType) f.field_type;
				if (delegate_type.delegate_symbol.has_target) {
					// create field to store delegate target
					var cdecl = new CCodeDeclaration ("gpointer");
					cdecl.add_declarator (new CCodeVariableDeclarator (get_delegate_target_cname  (f.get_cname ())));
					if (f.access != SymbolAccessibility.PRIVATE) {
						cdecl.modifiers = CCodeModifiers.EXTERN;
						header_type_member_declaration.append (cdecl);
					} else {
						cdecl.modifiers = CCodeModifiers.STATIC;
						source_type_member_declaration.append (cdecl);
					}
				}
			}

			if (f.initializer != null) {
				var rhs = (CCodeExpression) f.initializer.ccodenode;
				if (!is_constant_ccode_expression (rhs)) {
					if (f.parent_symbol is Class) {
						class_init_fragment.append (new CCodeExpressionStatement (new CCodeAssignment (lhs, rhs)));
					} else {
						f.error = true;
						Report.error (f.source_reference, "Non-constant field initializers not supported in this context");
						return;
					}
				}
			}
		}
	}

	private bool is_constant_ccode_expression (CCodeExpression cexpr) {
		if (cexpr is CCodeConstant) {
			return true;
		} else if (cexpr is CCodeBinaryExpression) {
			var cbinary = (CCodeBinaryExpression) cexpr;
			return is_constant_ccode_expression (cbinary.left) && is_constant_ccode_expression (cbinary.right);
		}

		var cparenthesized = (cexpr as CCodeParenthesizedExpression);
		return (null != cparenthesized && is_constant_ccode_expression (cparenthesized.inner));
	}

	/**
	 * Returns whether the passed cexpr is a pure expression, i.e. an
	 * expression without side-effects.
	 */
	public bool is_pure_ccode_expression (CCodeExpression cexpr) {
		if (cexpr is CCodeConstant || cexpr is CCodeIdentifier) {
			return true;
		} else if (cexpr is CCodeBinaryExpression) {
			var cbinary = (CCodeBinaryExpression) cexpr;
			return is_pure_ccode_expression (cbinary.left) && is_constant_ccode_expression (cbinary.right);
		} else if (cexpr is CCodeMemberAccess) {
			var cma = (CCodeMemberAccess) cexpr;
			return is_pure_ccode_expression (cma.inner);
		}

		var cparenthesized = (cexpr as CCodeParenthesizedExpression);
		return (null != cparenthesized && is_pure_ccode_expression (cparenthesized.inner));
	}

	public override void visit_method (Method m) {
		head.visit_method (m);
	}

	public override void visit_creation_method (CreationMethod m) {
		head.visit_creation_method (m);
	}

	public override void visit_formal_parameter (FormalParameter p) {
		p.accept_children (this);

		if (!p.ellipsis) {
			string ctypename = p.parameter_type.get_cname ();
			string cname = p.name;

			// pass non-simple structs always by reference
			if (p.parameter_type.data_type is Struct) {
				var st = (Struct) p.parameter_type.data_type;
				if (!st.is_simple_type () && p.direction == ParameterDirection.IN && !p.parameter_type.nullable) {
					ctypename += "*";
				}
			}

			if (p.direction != ParameterDirection.IN) {
				ctypename += "*";
			}

			p.ccodenode = new CCodeFormalParameter (cname, ctypename);
		} else {
			p.ccodenode = new CCodeFormalParameter.with_ellipsis ();
		}
	}

	public override void visit_property (Property prop) {
		int old_next_temp_var_id = next_temp_var_id;
		next_temp_var_id = 0;

		prop.accept_children (this);

		next_temp_var_id = old_next_temp_var_id;

		var cl = prop.parent_symbol as Class;
		if (cl != null && cl.is_subtype_of (gobject_type)
		    && prop.binding == MemberBinding.INSTANCE) {
			// GObject property
			// FIXME: omit real struct types for now since they
			// cannot be expressed as gobject property yet
			// don't register private properties
			if (!prop.property_type.is_real_struct_type ()
			    && prop.access != SymbolAccessibility.PRIVATE) {
				prop_enum.add_value (new CCodeEnumValue (prop.get_upper_case_cname ()));
			}
		}
	}

	public override void visit_property_accessor (PropertyAccessor acc) {
		current_property_accessor = acc;
		current_method_inner_error = false;

		var prop = (Property) acc.prop;

		bool returns_real_struct = prop.property_type.is_real_struct_type ();

		if (acc.readable && !returns_real_struct) {
			current_return_type = prop.property_type;
		} else {
			current_return_type = new VoidType ();
		}

		acc.accept_children (this);

		var t = (TypeSymbol) prop.parent_symbol;

		ReferenceType this_type;
		if (t is Class) {
			this_type = new ObjectType ((Class) t);
		} else {
			this_type = new ObjectType ((Interface) t);
		}
		var cselfparam = new CCodeFormalParameter ("self", this_type.get_cname ());
		var value_type = prop.property_type.copy ();
		CCodeFormalParameter cvalueparam;
		if (returns_real_struct) {
			cvalueparam = new CCodeFormalParameter ("value", value_type.get_cname () + "*");
		} else {
			cvalueparam = new CCodeFormalParameter ("value", value_type.get_cname ());
		}

		if (prop.is_abstract || prop.is_virtual) {
			CCodeFunctionDeclarator vdeclarator;

			if (acc.readable) {
				function = new CCodeFunction (acc.get_cname (), current_return_type.get_cname ());

				var vdecl = new CCodeDeclaration (current_return_type.get_cname ());
				vdeclarator = new CCodeFunctionDeclarator ("get_%s".printf (prop.name));
				vdecl.add_declarator (vdeclarator);
				type_struct.add_declaration (vdecl);
			} else {
				function = new CCodeFunction (acc.get_cname (), "void");

				var vdecl = new CCodeDeclaration ("void");
				vdeclarator = new CCodeFunctionDeclarator ("set_%s".printf (prop.name));
				vdecl.add_declarator (vdeclarator);
				type_struct.add_declaration (vdecl);
			}
			function.add_parameter (cselfparam);
			vdeclarator.add_parameter (cselfparam);
			if (acc.writable || acc.construction || returns_real_struct) {
				function.add_parameter (cvalueparam);
				vdeclarator.add_parameter (cvalueparam);
			}
			
			if (!prop.is_internal_symbol () && (acc.readable || acc.writable) && acc.access != SymbolAccessibility.PRIVATE) {
				// accessor function should be public if the property is a public symbol and it's not a construct-only setter
				header_type_member_declaration.append (function.copy ());
			} else {
				function.modifiers |= CCodeModifiers.STATIC;
				source_type_member_declaration.append (function.copy ());
			}
			
			var block = new CCodeBlock ();
			function.block = block;

			CCodeFunctionCall vcast = null;
			if (prop.parent_symbol is Interface) {
				var iface = (Interface) prop.parent_symbol;

				vcast = new CCodeFunctionCall (new CCodeIdentifier ("%s_GET_INTERFACE".printf (iface.get_upper_case_cname (null))));
			} else {
				var cl = (Class) prop.parent_symbol;

				vcast = new CCodeFunctionCall (new CCodeIdentifier ("%s_GET_CLASS".printf (cl.get_upper_case_cname (null))));
			}
			vcast.add_argument (new CCodeIdentifier ("self"));

			if (acc.readable) {
				var vcall = new CCodeFunctionCall (new CCodeMemberAccess.pointer (vcast, "get_%s".printf (prop.name)));
				vcall.add_argument (new CCodeIdentifier ("self"));
				if (returns_real_struct) {
					vcall.add_argument (new CCodeIdentifier ("value"));
					block.add_statement (new CCodeExpressionStatement (vcall));
				} else {
					block.add_statement (new CCodeReturnStatement (vcall));
				}
			} else {
				var vcall = new CCodeFunctionCall (new CCodeMemberAccess.pointer (vcast, "set_%s".printf (prop.name)));
				vcall.add_argument (new CCodeIdentifier ("self"));
				vcall.add_argument (new CCodeIdentifier ("value"));
				block.add_statement (new CCodeExpressionStatement (vcall));
			}

			source_type_member_definition.append (function);
		}

		if (!prop.is_abstract) {
			bool is_virtual = prop.base_property != null || prop.base_interface_property != null;

			string cname;
			if (is_virtual) {
				if (acc.readable) {
					cname = "%s_real_get_%s".printf (t.get_lower_case_cname (null), prop.name);
				} else {
					cname = "%s_real_set_%s".printf (t.get_lower_case_cname (null), prop.name);
				}
			} else {
				cname = acc.get_cname ();
			}

			if (acc.writable || acc.construction || returns_real_struct) {
				function = new CCodeFunction (cname, "void");
			} else {
				function = new CCodeFunction (cname, prop.property_type.get_cname ());
			}

			ObjectType base_type = null;
			if (prop.binding == MemberBinding.INSTANCE) {
				if (is_virtual) {
					if (prop.base_property != null) {
						base_type = new ObjectType ((ObjectTypeSymbol) prop.base_property.parent_symbol);
					} else if (prop.base_interface_property != null) {
						base_type = new ObjectType ((ObjectTypeSymbol) prop.base_interface_property.parent_symbol);
					}
					function.modifiers |= CCodeModifiers.STATIC;
					function.add_parameter (new CCodeFormalParameter ("base", base_type.get_cname ()));
				} else {
					function.add_parameter (cselfparam);
				}
			}
			if (acc.writable || acc.construction || returns_real_struct) {
				function.add_parameter (cvalueparam);
			}

			if (!is_virtual) {
				if (!prop.is_internal_symbol () && (acc.readable || acc.writable) && acc.access != SymbolAccessibility.PRIVATE) {
					// accessor function should be public if the property is a public symbol and it's not a construct-only setter
					header_type_member_declaration.append (function.copy ());
				} else {
					function.modifiers |= CCodeModifiers.STATIC;
					source_type_member_declaration.append (function.copy ());
				}
			}

			function.block = (CCodeBlock) acc.body.ccodenode;

			if (is_virtual) {
				var cdecl = new CCodeDeclaration (this_type.get_cname ());
				cdecl.add_declarator (new CCodeVariableDeclarator.with_initializer ("self", transform_expression (new CCodeIdentifier ("base"), base_type, this_type)));
				function.block.prepend_statement (cdecl);
			}

			if (current_method_inner_error) {
				var cdecl = new CCodeDeclaration ("GError *");
				cdecl.add_declarator (new CCodeVariableDeclarator.with_initializer ("inner_error", new CCodeConstant ("NULL")));
				function.block.prepend_statement (cdecl);
			}

			if (prop.binding == MemberBinding.INSTANCE && !is_virtual) {
				if (returns_real_struct) {
					function.block.prepend_statement (create_property_type_check_statement (prop, false, t, true, "self"));
				} else {
					function.block.prepend_statement (create_property_type_check_statement (prop, acc.readable, t, true, "self"));
				}
			}

			// notify on property changes
			var typesymbol = (TypeSymbol) prop.parent_symbol;
			if (typesymbol.is_subtype_of (gobject_type) &&
			    prop.notify &&
			    prop.access != SymbolAccessibility.PRIVATE && // FIXME: use better means to detect gobject properties
			    prop.binding == MemberBinding.INSTANCE &&
			    !prop.property_type.is_real_struct_type () &&
			    (acc.writable || acc.construction)) {
				var notify_call = new CCodeFunctionCall (new CCodeIdentifier ("g_object_notify"));
				notify_call.add_argument (new CCodeCastExpression (new CCodeIdentifier ("self"), "GObject *"));
				notify_call.add_argument (prop.get_canonical_cconstant ());
				function.block.add_statement (new CCodeExpressionStatement (notify_call));
			}

			source_type_member_definition.append (function);
		}

		current_property_accessor = null;
		current_return_type = null;
	}

	public override void visit_signal (Signal sig) {
		head.visit_signal (sig);
	}

	public override void visit_constructor (Constructor c) {
		current_method_inner_error = false;
		in_constructor = true;

		if (c.binding == MemberBinding.CLASS || c.binding == MemberBinding.STATIC) {
			in_static_or_class_ctor = true;
		}
		c.accept_children (this);
		in_static_or_class_ctor = false;

		in_constructor = false;

		var cl = (Class) c.parent_symbol;

		if (c.binding == MemberBinding.INSTANCE) {
			function = new CCodeFunction ("%s_constructor".printf (cl.get_lower_case_cname (null)), "GObject *");
			function.modifiers = CCodeModifiers.STATIC;
		
			function.add_parameter (new CCodeFormalParameter ("type", "GType"));
			function.add_parameter (new CCodeFormalParameter ("n_construct_properties", "guint"));
			function.add_parameter (new CCodeFormalParameter ("construct_properties", "GObjectConstructParam *"));
		
			source_type_member_declaration.append (function.copy ());


			var cblock = new CCodeBlock ();
			var cdecl = new CCodeDeclaration ("GObject *");
			cdecl.add_declarator (new CCodeVariableDeclarator ("obj"));
			cblock.add_statement (cdecl);

			cdecl = new CCodeDeclaration ("%sClass *".printf (cl.get_cname ()));
			cdecl.add_declarator (new CCodeVariableDeclarator ("klass"));
			cblock.add_statement (cdecl);

			cdecl = new CCodeDeclaration ("GObjectClass *");
			cdecl.add_declarator (new CCodeVariableDeclarator ("parent_class"));
			cblock.add_statement (cdecl);


			var ccall = new CCodeFunctionCall (new CCodeIdentifier ("g_type_class_peek"));
			ccall.add_argument (new CCodeIdentifier (cl.get_type_id ()));
			var ccast = new CCodeFunctionCall (new CCodeIdentifier ("%s_CLASS".printf (cl.get_upper_case_cname (null))));
			ccast.add_argument (ccall);
			cblock.add_statement (new CCodeExpressionStatement (new CCodeAssignment (new CCodeIdentifier ("klass"), ccast)));

			ccall = new CCodeFunctionCall (new CCodeIdentifier ("g_type_class_peek_parent"));
			ccall.add_argument (new CCodeIdentifier ("klass"));
			ccast = new CCodeFunctionCall (new CCodeIdentifier ("G_OBJECT_CLASS"));
			ccast.add_argument (ccall);
			cblock.add_statement (new CCodeExpressionStatement (new CCodeAssignment (new CCodeIdentifier ("parent_class"), ccast)));

		
			ccall = new CCodeFunctionCall (new CCodeMemberAccess.pointer (new CCodeIdentifier ("parent_class"), "constructor"));
			ccall.add_argument (new CCodeIdentifier ("type"));
			ccall.add_argument (new CCodeIdentifier ("n_construct_properties"));
			ccall.add_argument (new CCodeIdentifier ("construct_properties"));
			cblock.add_statement (new CCodeExpressionStatement (new CCodeAssignment (new CCodeIdentifier ("obj"), ccall)));


			ccall = new InstanceCast (new CCodeIdentifier ("obj"), cl);

			cdecl = new CCodeDeclaration ("%s *".printf (cl.get_cname ()));
			cdecl.add_declarator (new CCodeVariableDeclarator.with_initializer ("self", ccall));
		
			cblock.add_statement (cdecl);

			if (current_method_inner_error) {
				/* always separate error parameter and inner_error local variable
				 * as error may be set to NULL but we're always interested in inner errors
				 */
				var cdecl = new CCodeDeclaration ("GError *");
				cdecl.add_declarator (new CCodeVariableDeclarator.with_initializer ("inner_error", new CCodeConstant ("NULL")));
				cblock.add_statement (cdecl);
			}


			cblock.add_statement (c.body.ccodenode);
		
			cblock.add_statement (new CCodeReturnStatement (new CCodeIdentifier ("obj")));
		
			function.block = cblock;

			if (c.source_reference.comment != null) {
				source_type_member_definition.append (new CCodeComment (c.source_reference.comment));
			}
			source_type_member_definition.append (function);
		} else if (c.binding == MemberBinding.CLASS) {
			// class constructor

			var base_init = new CCodeFunction ("%s_base_init".printf (cl.get_lower_case_cname (null)), "void");
			base_init.add_parameter (new CCodeFormalParameter ("klass", "%sClass *".printf (cl.get_cname ())));
			base_init.modifiers = CCodeModifiers.STATIC;

			source_type_member_declaration.append (base_init.copy ());

			var block = (CCodeBlock) c.body.ccodenode;
			if (current_method_inner_error) {
				/* always separate error parameter and inner_error local variable
				 * as error may be set to NULL but we're always interested in inner errors
				 */
				var cdecl = new CCodeDeclaration ("GError *");
				cdecl.add_declarator (new CCodeVariableDeclarator.with_initializer ("inner_error", new CCodeConstant ("NULL")));
				block.prepend_statement (cdecl);
			}

			base_init.block = block;
		
			source_type_member_definition.append (base_init);
		} else if (c.binding == MemberBinding.STATIC) {
			// static class constructor
			// add to class_init

			if (current_method_inner_error) {
				/* always separate error parameter and inner_error local variable
				 * as error may be set to NULL but we're always interested in inner errors
				 */
				var cdecl = new CCodeDeclaration ("GError *");
				cdecl.add_declarator (new CCodeVariableDeclarator.with_initializer ("inner_error", new CCodeConstant ("NULL")));
				class_init_fragment.append (cdecl);
			}

			class_init_fragment.append (c.body.ccodenode);
		} else {
			Report.error (c.source_reference, "internal error: constructors must have instance, class, or static binding");
		}
	}

	public override void visit_destructor (Destructor d) {
		current_method_inner_error = false;

		d.accept_children (this);

		CCodeFragment cfrag = new CCodeFragment ();

		if (current_method_inner_error) {
			var cdecl = new CCodeDeclaration ("GError *");
			cdecl.add_declarator (new CCodeVariableDeclarator.with_initializer ("inner_error", new CCodeConstant ("NULL")));
			cfrag.append (cdecl);
		}

		cfrag.append (d.body.ccodenode);

		d.ccodenode = cfrag;
	}

	public override void visit_block (Block b) {
		current_symbol = b;

		b.accept_children (this);

		var local_vars = b.get_local_variables ();
		foreach (LocalVariable local in local_vars) {
			local.active = false;
		}
		
		var cblock = new CCodeBlock ();
		
		foreach (CodeNode stmt in b.get_statements ()) {
			if (stmt.error) {
				continue;
			}

			var src = stmt.source_reference;
			if (src != null && src.comment != null) {
				cblock.add_statement (new CCodeComment (src.comment));
			}
			
			if (stmt.ccodenode is CCodeFragment) {
				foreach (CCodeNode cstmt in ((CCodeFragment) stmt.ccodenode).get_children ()) {
					cblock.add_statement (cstmt);
				}
			} else {
				cblock.add_statement (stmt.ccodenode);
			}
		}

		foreach (LocalVariable local in local_vars) {
			if (requires_destroy (local.variable_type)) {
				var ma = new MemberAccess.simple (local.name);
				ma.symbol_reference = local;
				cblock.add_statement (new CCodeExpressionStatement (get_unref_expression (new CCodeIdentifier (get_variable_cname (local.name)), local.variable_type, ma)));
			}
		}

		if (b.parent_symbol is Method) {
			var m = (Method) b.parent_symbol;
			foreach (FormalParameter param in m.get_parameters ()) {
				if (requires_destroy (param.parameter_type) && param.direction == ParameterDirection.IN) {
					var ma = new MemberAccess.simple (param.name);
					ma.symbol_reference = param;
					cblock.add_statement (new CCodeExpressionStatement (get_unref_expression (new CCodeIdentifier (get_variable_cname (param.name)), param.parameter_type, ma)));
				}
			}
		}

		b.ccodenode = cblock;

		current_symbol = current_symbol.parent_symbol;
	}

	public override void visit_empty_statement (EmptyStatement stmt) {
		stmt.ccodenode = new CCodeEmptyStatement ();
	}

	public override void visit_declaration_statement (DeclarationStatement stmt) {
		stmt.ccodenode = stmt.declaration.ccodenode;

		var local = stmt.declaration as LocalVariable;
		if (local != null && local.initializer != null) {
			create_temp_decl (stmt, local.initializer.temp_vars);
		}

		create_temp_decl (stmt, temp_vars);
		temp_vars.clear ();
	}

	public string get_variable_cname (string name) {
		if (c_keywords.contains (name)) {
			return name + "_";
		} else {
			return name;
		}
	}

	public override void visit_local_variable (LocalVariable local) {
		local.accept_children (this);

		if (local.variable_type is ArrayType) {
			// create variables to store array dimensions
			var array_type = (ArrayType) local.variable_type;
			
			for (int dim = 1; dim <= array_type.rank; dim++) {
				var len_var = new LocalVariable (int_type.copy (), head.get_array_length_cname (local.name, dim));
				temp_vars.insert (0, len_var);
			}
		} else if (local.variable_type is DelegateType) {
			var deleg_type = (DelegateType) local.variable_type;
			var d = deleg_type.delegate_symbol;
			if (d.has_target) {
				// create variable to store delegate target
				var target_var = new LocalVariable (new PointerType (new VoidType ()), get_delegate_target_cname (local.name));
				temp_vars.insert (0, target_var);
			}
		}
	
		CCodeExpression rhs = null;
		if (local.initializer != null && local.initializer.ccodenode != null) {
			rhs = (CCodeExpression) local.initializer.ccodenode;

			if (local.variable_type is ArrayType) {
				var array_type = (ArrayType) local.variable_type;

				var ccomma = new CCodeCommaExpression ();

				var temp_var = get_temp_variable (local.variable_type, true, local);
				temp_vars.insert (0, temp_var);
				ccomma.append_expression (new CCodeAssignment (new CCodeIdentifier (temp_var.name), rhs));

				for (int dim = 1; dim <= array_type.rank; dim++) {
					var lhs_array_len = new CCodeIdentifier (head.get_array_length_cname (local.name, dim));
					var rhs_array_len = head.get_array_length_cexpression (local.initializer, dim);
					ccomma.append_expression (new CCodeAssignment (lhs_array_len, rhs_array_len));
				}
				
				ccomma.append_expression (new CCodeIdentifier (temp_var.name));
				
				rhs = ccomma;
			} else if (local.variable_type is DelegateType) {
				var deleg_type = (DelegateType) local.variable_type;
				var d = deleg_type.delegate_symbol;
				if (d.has_target) {
					var ccomma = new CCodeCommaExpression ();

					var temp_var = get_temp_variable (local.variable_type, true, local);
					temp_vars.insert (0, temp_var);
					ccomma.append_expression (new CCodeAssignment (new CCodeIdentifier (temp_var.name), rhs));

					var lhs_delegate_target = new CCodeIdentifier (get_delegate_target_cname (local.name));
					var rhs_delegate_target = get_delegate_target_cexpression (local.initializer);
					ccomma.append_expression (new CCodeAssignment (lhs_delegate_target, rhs_delegate_target));
				
					ccomma.append_expression (new CCodeIdentifier (temp_var.name));
				
					rhs = ccomma;
				}
			}
		} else if (local.variable_type.is_reference_type_or_type_parameter ()) {
			rhs = new CCodeConstant ("NULL");

			if (local.variable_type is ArrayType) {
				// initialize array length variables
				var array_type = (ArrayType) local.variable_type;

				var ccomma = new CCodeCommaExpression ();

				for (int dim = 1; dim <= array_type.rank; dim++) {
					ccomma.append_expression (new CCodeAssignment (new CCodeIdentifier (head.get_array_length_cname (local.name, dim)), new CCodeConstant ("0")));
				}

				ccomma.append_expression (rhs);

				rhs = ccomma;
			}
		}
			
		var cvar = new CCodeVariableDeclarator.with_initializer (get_variable_cname (local.name), rhs);

		var cfrag = new CCodeFragment ();
		var cdecl = new CCodeDeclaration (local.variable_type.get_cname ());
		cdecl.add_declarator (cvar);
		cfrag.append (cdecl);

		if (local.initializer != null && local.initializer.tree_can_fail) {
			add_simple_check (local.initializer, cfrag);
		}

		/* try to initialize uninitialized variables */
		if (cvar.initializer == null) {
			cvar.initializer = default_value_for_type (local.variable_type, true);
		}

		local.ccodenode = cfrag;

		local.active = true;
	}

	public override void visit_initializer_list (InitializerList list) {
		list.accept_children (this);

		if (list.target_type.data_type is Struct) {
			/* initializer is used as struct initializer */
			var st = (Struct) list.target_type.data_type;

			var clist = new CCodeInitializerList ();

			var field_it = st.get_fields ().iterator ();
			foreach (Expression expr in list.get_initializers ()) {
				Field field = null;
				while (field == null) {
					field_it.next ();
					field = field_it.get ();
					if (field.binding != MemberBinding.INSTANCE) {
						// we only initialize instance fields
						field = null;
					}
				}

				var cexpr = (CCodeExpression) expr.ccodenode;

				string ctype = field.get_ctype ();
				if (ctype != null) {
					cexpr = new CCodeCastExpression (cexpr, ctype);
				}

				clist.append (cexpr);
			}

			list.ccodenode = clist;
		} else {
			var clist = new CCodeInitializerList ();
			foreach (Expression expr in list.get_initializers ()) {
				clist.append ((CCodeExpression) expr.ccodenode);
			}
			list.ccodenode = clist;
		}
	}

	public LocalVariable get_temp_variable (DataType type, bool value_owned = true, CodeNode? node_reference = null) {
		var var_type = type.copy ();
		var_type.value_owned = value_owned;
		var local = new LocalVariable (var_type, "_tmp%d".printf (next_temp_var_id));

		if (node_reference != null) {
			local.source_reference = node_reference.source_reference;
		}

		next_temp_var_id++;
		
		return local;
	}

	private CCodeExpression get_type_id_expression (DataType type) {
		if (type.data_type != null) {
			return new CCodeIdentifier (type.data_type.get_type_id ());
		} else if (type.type_parameter != null) {
			string var_name = "%s_type".printf (type.type_parameter.name.down ());
			return new CCodeMemberAccess.pointer (new CCodeMemberAccess.pointer (new CCodeIdentifier ("self"), "priv"), var_name);
		} else {
			return new CCodeIdentifier ("G_TYPE_NONE");
		}
	}

	public CCodeExpression? get_dup_func_expression (DataType type, SourceReference? source_reference) {
		var cl = type.data_type as Class;
		if (type is ErrorType) {
			return new CCodeIdentifier ("g_error_copy");
		} else if (type.data_type != null) {
			string dup_function;
			if (type.data_type.is_reference_counting ()) {
				dup_function = type.data_type.get_ref_function ();
				if (type.data_type is Interface && dup_function == null) {
					Report.error (source_reference, "missing class prerequisite for interface `%s'".printf (type.data_type.get_full_name ()));
					return null;
				}
			} else if (cl != null && cl.is_immutable) {
				// allow duplicates of immutable instances as for example strings
				dup_function = type.data_type.get_dup_function ();
			} else if (type is ValueType) {
				if (type.nullable) {
					dup_function = generate_struct_dup_wrapper ((ValueType) type);
				} else {
					dup_function = "";
				}
			} else {
				// duplicating non-reference counted objects may cause side-effects (and performance issues)
				Report.error (source_reference, "duplicating %s instance, use weak variable or explicitly invoke copy method".printf (type.data_type.name));
				return null;
			}

			return new CCodeIdentifier (dup_function);
		} else if (type.type_parameter != null && current_type_symbol is Class) {
			string func_name = "%s_dup_func".printf (type.type_parameter.name.down ());
			return new CCodeMemberAccess.pointer (new CCodeMemberAccess.pointer (new CCodeIdentifier ("self"), "priv"), func_name);
		} else if (type is ArrayType) {
			return new CCodeIdentifier (generate_array_dup_wrapper ((ArrayType) type));
		} else if (type is PointerType) {
			var pointer_type = (PointerType) type;
			return get_dup_func_expression (pointer_type.base_type, source_reference);
		} else {
			return new CCodeConstant ("NULL");
		}
	}

	string generate_array_dup_wrapper (ArrayType array_type) {
		string dup_func = "_vala_array_dup%d".printf (++next_array_dup_id);

		if (!add_wrapper (dup_func)) {
			// wrapper already defined
			return dup_func;
		}

		// declaration

		var function = new CCodeFunction (dup_func, array_type.get_cname ());
		function.modifiers = CCodeModifiers.STATIC;

		function.add_parameter (new CCodeFormalParameter ("self", array_type.get_cname ()));
		// total length over all dimensions
		function.add_parameter (new CCodeFormalParameter ("length", "int"));

		// definition

		var block = new CCodeBlock ();

		if (requires_copy (array_type.element_type)) {
			var old_temp_vars = temp_vars;

			var cdecl = new CCodeDeclaration (array_type.get_cname ());
			var cvardecl = new CCodeVariableDeclarator ("result");
			cdecl.add_declarator (cvardecl);
			var gnew = new CCodeFunctionCall (new CCodeIdentifier ("g_new0"));
			gnew.add_argument (new CCodeIdentifier (array_type.element_type.get_cname ()));
			gnew.add_argument (new CCodeIdentifier ("length"));
			cvardecl.initializer = gnew;
			block.add_statement (cdecl);

			var idx_decl = new CCodeDeclaration ("int");
			idx_decl.add_declarator (new CCodeVariableDeclarator ("i"));
			block.add_statement (idx_decl);

			var loop_body = new CCodeBlock ();
			loop_body.add_statement (new CCodeExpressionStatement (new CCodeAssignment (new CCodeElementAccess (new CCodeIdentifier ("result"), new CCodeIdentifier ("i")), get_ref_cexpression (array_type.element_type, new CCodeElementAccess (new CCodeIdentifier ("self"), new CCodeIdentifier ("i")), null, array_type))));

			var cfor = new CCodeForStatement (new CCodeBinaryExpression (CCodeBinaryOperator.LESS_THAN, new CCodeIdentifier ("i"), new CCodeIdentifier ("length")), loop_body);
			cfor.add_initializer (new CCodeAssignment (new CCodeIdentifier ("i"), new CCodeConstant ("0")));
			cfor.add_iterator (new CCodeUnaryExpression (CCodeUnaryOperator.POSTFIX_INCREMENT, new CCodeIdentifier ("i")));
			block.add_statement (cfor);

			block.add_statement (new CCodeReturnStatement (new CCodeIdentifier ("result")));

			var cfrag = new CCodeFragment ();
			append_temp_decl (cfrag, temp_vars);
			block.add_statement (cfrag);
			temp_vars = old_temp_vars;
		} else {
			var dup_call = new CCodeFunctionCall (new CCodeIdentifier ("g_memdup"));
			dup_call.add_argument (new CCodeIdentifier ("self"));

			var sizeof_call = new CCodeFunctionCall (new CCodeIdentifier ("sizeof"));
			sizeof_call.add_argument (new CCodeIdentifier (array_type.element_type.get_cname ()));
			dup_call.add_argument (new CCodeBinaryExpression (CCodeBinaryOperator.MUL, new CCodeIdentifier ("length"), sizeof_call));

			block.add_statement (new CCodeReturnStatement (dup_call));
		}

		// append to file

		source_type_member_declaration.append (function.copy ());

		function.block = block;
		source_type_member_definition.append (function);

		return dup_func;
	}

	private string generate_struct_dup_wrapper (ValueType value_type) {
		string dup_func = "_%sdup".printf (value_type.type_symbol.get_lower_case_cprefix ());

		if (!add_wrapper (dup_func)) {
			// wrapper already defined
			return dup_func;
		}

		// declaration

		var function = new CCodeFunction (dup_func, value_type.get_cname ());
		function.modifiers = CCodeModifiers.STATIC;

		function.add_parameter (new CCodeFormalParameter ("self", value_type.get_cname ()));

		// definition

		var block = new CCodeBlock ();

		var dup_call = new CCodeFunctionCall (new CCodeIdentifier ("g_memdup"));
		dup_call.add_argument (new CCodeIdentifier ("self"));

		var sizeof_call = new CCodeFunctionCall (new CCodeIdentifier ("sizeof"));
		sizeof_call.add_argument (new CCodeIdentifier (value_type.type_symbol.get_cname ()));
		dup_call.add_argument (sizeof_call);

		block.add_statement (new CCodeReturnStatement (dup_call));

		// append to file

		source_type_member_declaration.append (function.copy ());

		function.block = block;
		source_type_member_definition.append (function);

		return dup_func;
	}

	public CCodeExpression? get_destroy_func_expression (DataType type) {
		if (type.data_type == glist_type || type.data_type == gslist_type) {
			// create wrapper function to free list elements if necessary

			bool elements_require_free = false;
			CCodeExpression element_destroy_func_expression = null;

			foreach (DataType type_arg in type.get_type_arguments ()) {
				elements_require_free = requires_destroy (type_arg);
				if (elements_require_free) {
					element_destroy_func_expression = get_destroy_func_expression (type_arg);
				}
			}
			
			if (elements_require_free && element_destroy_func_expression is CCodeIdentifier) {
				return new CCodeIdentifier (generate_glist_free_wrapper (type, (CCodeIdentifier) element_destroy_func_expression));
			} else {
				return new CCodeIdentifier (type.data_type.get_free_function ());
			}
		} else if (type is ErrorType) {
			return new CCodeIdentifier ("g_error_free");
		} else if (type.data_type != null) {
			string unref_function;
			if (type is ReferenceType) {
				if (type.data_type.is_reference_counting ()) {
					unref_function = type.data_type.get_unref_function ();
					if (type.data_type is Interface && unref_function == null) {
						Report.error (type.source_reference, "missing class prerequisite for interface `%s'".printf (type.data_type.get_full_name ()));
						return null;
					}
				} else {
					unref_function = type.data_type.get_free_function ();
				}
			} else {
				if (type.nullable) {
					unref_function = type.data_type.get_free_function ();
					if (unref_function == null) {
						unref_function = "g_free";
					}
				} else {
					var st = (Struct) type.data_type;
					unref_function = st.get_destroy_function ();
				}
			}
			if (unref_function == null) {
				return new CCodeConstant ("NULL");
			}
			return new CCodeIdentifier (unref_function);
		} else if (type.type_parameter != null && current_type_symbol is Class) {
			string func_name = "%s_destroy_func".printf (type.type_parameter.name.down ());
			return new CCodeMemberAccess.pointer (new CCodeMemberAccess.pointer (new CCodeIdentifier ("self"), "priv"), func_name);
		} else if (type is ArrayType) {
			return new CCodeIdentifier ("g_free");
		} else if (type is PointerType) {
			return new CCodeIdentifier ("g_free");
		} else {
			return new CCodeConstant ("NULL");
		}
	}

	private string generate_glist_free_wrapper (DataType list_type, CCodeIdentifier element_destroy_func_expression) {
		string destroy_func = "_%s_%s".printf (list_type.data_type.get_free_function (), element_destroy_func_expression.name);

		if (!add_wrapper (destroy_func)) {
			// wrapper already defined
			return destroy_func;
		}

		// declaration

		var function = new CCodeFunction (destroy_func, "void");
		function.modifiers = CCodeModifiers.STATIC;

		var cparam_map = new HashMap<int,CCodeFormalParameter> (direct_hash, direct_equal);

		function.add_parameter (new CCodeFormalParameter ("self", list_type.get_cname ()));

		// definition

		var block = new CCodeBlock ();

		CCodeFunctionCall element_free_call;
		if (list_type.data_type == glist_type) {
			element_free_call = new CCodeFunctionCall (new CCodeIdentifier ("g_list_foreach"));
		} else {
			element_free_call = new CCodeFunctionCall (new CCodeIdentifier ("g_slist_foreach"));
		}
		element_free_call.add_argument (new CCodeIdentifier ("self"));
		element_free_call.add_argument (new CCodeCastExpression (element_destroy_func_expression, "GFunc"));
		element_free_call.add_argument (new CCodeConstant ("NULL"));
		block.add_statement (new CCodeExpressionStatement (element_free_call));

		var cfreecall = new CCodeFunctionCall (new CCodeIdentifier (list_type.data_type.get_free_function ()));
		cfreecall.add_argument (new CCodeIdentifier ("self"));
		block.add_statement (new CCodeExpressionStatement (cfreecall));

		// append to file

		source_type_member_declaration.append (function.copy ());

		function.block = block;
		source_type_member_definition.append (function);

		return destroy_func;
	}

	public CCodeExpression get_unref_expression (CCodeExpression cvar, DataType type, Expression expr) {
		var ccall = new CCodeFunctionCall (get_destroy_func_expression (type));

		if (type is ValueType && !type.nullable) {
			// normal value type, no null check
			ccall.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, cvar));
			return ccall;
		}

		/* (foo == NULL ? NULL : foo = (unref (foo), NULL)) */
		
		/* can be simplified to
		 * foo = (unref (foo), NULL)
		 * if foo is of static type non-null
		 */

		var cisnull = new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, cvar, new CCodeConstant ("NULL"));
		if (type.type_parameter != null) {
			if (!(current_type_symbol is Class) || current_class.is_compact) {
				return new CCodeConstant ("NULL");
			}

			// unref functions are optional for type parameters
			var cunrefisnull = new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, get_destroy_func_expression (type), new CCodeConstant ("NULL"));
			cisnull = new CCodeBinaryExpression (CCodeBinaryOperator.OR, cisnull, cunrefisnull);
		}

		ccall.add_argument (cvar);

		/* set freed references to NULL to prevent further use */
		var ccomma = new CCodeCommaExpression ();

		if (type.data_type == gstringbuilder_type) {
			ccall.add_argument (new CCodeConstant ("TRUE"));
		} else if (type is ArrayType) {
			var array_type = (ArrayType) type;
			if (array_type.element_type.data_type == null || array_type.element_type.data_type.is_reference_type ()) {
				requires_array_free = true;

				bool first = true;
				CCodeExpression csizeexpr = null;
				for (int dim = 1; dim <= array_type.rank; dim++) {
					if (first) {
						csizeexpr = head.get_array_length_cexpression (expr, dim);
						first = false;
					} else {
						csizeexpr = new CCodeBinaryExpression (CCodeBinaryOperator.MUL, csizeexpr, head.get_array_length_cexpression (expr, dim));
					}
				}

				ccall.call = new CCodeIdentifier ("_vala_array_free");
				ccall.add_argument (csizeexpr);
				ccall.add_argument (new CCodeCastExpression (get_destroy_func_expression (array_type.element_type), "GDestroyNotify"));
			}
		}
		
		ccomma.append_expression (ccall);
		ccomma.append_expression (new CCodeConstant ("NULL"));
		
		var cassign = new CCodeAssignment (cvar, ccomma);

		// g_free (NULL) is allowed
		bool uses_gfree = (type.data_type != null && !type.data_type.is_reference_counting () && type.data_type.get_free_function () == "g_free");
		uses_gfree = uses_gfree || type is ArrayType;
		if (uses_gfree) {
			return new CCodeParenthesizedExpression (cassign);
		}

		return new CCodeConditionalExpression (cisnull, new CCodeConstant ("NULL"), new CCodeParenthesizedExpression (cassign));
	}
	
	public override void visit_end_full_expression (Expression expr) {
		/* expr is a full expression, i.e. an initializer, the
		 * expression in an expression statement, the controlling
		 * expression in if, while, for, or foreach statements
		 *
		 * we unref temporary variables at the end of a full
		 * expression
		 */
		
		/* can't automatically deep copy lists yet, so do it
		 * manually for now
		 * replace with
		 * expr.temp_vars = temp_vars;
		 * when deep list copying works
		 */
		expr.temp_vars.clear ();
		foreach (LocalVariable local in temp_vars) {
			expr.temp_vars.add (local);
		}
		temp_vars.clear ();

		if (((Gee.List<LocalVariable>) temp_ref_vars).size == 0) {
			/* nothing to do without temporary variables */
			return;
		}

		var expr_type = expr.value_type;
		if (expr.target_type != null) {
			expr_type = expr.target_type;
		}

		var full_expr_var = get_temp_variable (expr_type, true, expr);
		expr.temp_vars.add (full_expr_var);
		
		var expr_list = new CCodeCommaExpression ();
		expr_list.append_expression (new CCodeAssignment (new CCodeIdentifier (full_expr_var.name), (CCodeExpression) expr.ccodenode));
		
		foreach (LocalVariable local in temp_ref_vars) {
			var ma = new MemberAccess.simple (local.name);
			ma.symbol_reference = local;
			expr_list.append_expression (get_unref_expression (new CCodeIdentifier (local.name), local.variable_type, ma));
		}
		
		expr_list.append_expression (new CCodeIdentifier (full_expr_var.name));
		
		expr.ccodenode = expr_list;
		
		temp_ref_vars.clear ();
	}
	
	private void append_temp_decl (CCodeFragment cfrag, Gee.List<LocalVariable> temp_vars) {
		foreach (LocalVariable local in temp_vars) {
			var cdecl = new CCodeDeclaration (local.variable_type.get_cname ());
		
			var vardecl = new CCodeVariableDeclarator (local.name);
			// sets #line
			local.ccodenode = vardecl;
			cdecl.add_declarator (vardecl);

			var st = local.variable_type.data_type as Struct;

			if (local.variable_type.is_reference_type_or_type_parameter ()) {
				vardecl.initializer = new CCodeConstant ("NULL");
			} else if (st != null && !st.is_simple_type ()) {
				// 0-initialize struct with struct initializer { 0 }
				// necessary as they will be passed by reference
				var clist = new CCodeInitializerList ();
				clist.append (new CCodeConstant ("0"));

				vardecl.initializer = clist;
			}
			
			cfrag.append (cdecl);
		}
	}

	private void add_simple_check (CodeNode node, CCodeFragment cfrag) {
		current_method_inner_error = true;

		var cprint_frag = new CCodeFragment ();
		var ccritical = new CCodeFunctionCall (new CCodeIdentifier ("g_critical"));
		ccritical.add_argument (new CCodeConstant ("\"file %s: line %d: uncaught error: %s\""));
		ccritical.add_argument (new CCodeConstant ("__FILE__"));
		ccritical.add_argument (new CCodeConstant ("__LINE__"));
		ccritical.add_argument (new CCodeMemberAccess.pointer (new CCodeIdentifier ("inner_error"), "message"));
		cprint_frag.append (new CCodeExpressionStatement (ccritical));
		var cclear = new CCodeFunctionCall (new CCodeIdentifier ("g_clear_error"));
		cclear.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, new CCodeIdentifier ("inner_error")));
		cprint_frag.append (new CCodeExpressionStatement (cclear));

		if (current_try != null) {
			// surrounding try found
			// TODO might be the wrong one when using nested try statements

			var cerror_block = new CCodeBlock ();
			foreach (CatchClause clause in current_try.get_catch_clauses ()) {
				// go to catch clause if error domain matches
				var cgoto_stmt = new CCodeGotoStatement (clause.clabel_name);

				if (clause.error_type.equals (gerror_type)) {
					// general catch clause
					cerror_block.add_statement (cgoto_stmt);
				} else {
					var ccond = new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, new CCodeMemberAccess.pointer (new CCodeIdentifier ("inner_error"), "domain"), new CCodeIdentifier (clause.error_type.data_type.get_upper_case_cname ()));

					var cgoto_block = new CCodeBlock ();
					cgoto_block.add_statement (cgoto_stmt);

					cerror_block.add_statement (new CCodeIfStatement (ccond, cgoto_block));
				}
			}
			// print critical message if no catch clause matches
			cerror_block.add_statement (cprint_frag);

			// check error domain if expression failed
			var ccond = new CCodeBinaryExpression (CCodeBinaryOperator.INEQUALITY, new CCodeIdentifier ("inner_error"), new CCodeConstant ("NULL"));

			cfrag.append (new CCodeIfStatement (ccond, cerror_block));
		} else if (current_method != null && current_method.get_error_types ().size > 0) {
			// current method can fail, propagate error
			// TODO ensure one of the error domains matches

			var cpropagate = new CCodeFunctionCall (new CCodeIdentifier ("g_propagate_error"));
			cpropagate.add_argument (new CCodeIdentifier ("error"));
			cpropagate.add_argument (new CCodeIdentifier ("inner_error"));

			var cerror_block = new CCodeBlock ();
			cerror_block.add_statement (new CCodeExpressionStatement (cpropagate));

			// free local variables
			var free_frag = new CCodeFragment ();
			append_local_free (current_symbol, free_frag, false);
			cerror_block.add_statement (free_frag);

			if (current_return_type is VoidType) {
				cerror_block.add_statement (new CCodeReturnStatement ());
			} else {
				cerror_block.add_statement (new CCodeReturnStatement (default_value_for_type (current_return_type, false)));
			}

			var ccond = new CCodeBinaryExpression (CCodeBinaryOperator.INEQUALITY, new CCodeIdentifier ("inner_error"), new CCodeConstant ("NULL"));

			cfrag.append (new CCodeIfStatement (ccond, cerror_block));
		} else {
			// unhandled error

			var cerror_block = new CCodeBlock ();
			// print critical message
			cerror_block.add_statement (cprint_frag);

			// check error domain if expression failed
			var ccond = new CCodeBinaryExpression (CCodeBinaryOperator.INEQUALITY, new CCodeIdentifier ("inner_error"), new CCodeConstant ("NULL"));

			cfrag.append (new CCodeIfStatement (ccond, cerror_block));
		}
	}

	public override void visit_expression_statement (ExpressionStatement stmt) {
		if (stmt.expression.error) {
			stmt.error = true;
			return;
		}

		stmt.ccodenode = new CCodeExpressionStatement ((CCodeExpression) stmt.expression.ccodenode);

		var invoc = stmt.expression as InvocationExpression;
		if (invoc != null) {
			var m = invoc.call.symbol_reference as Method;
			var ma = invoc.call as MemberAccess;
			if (m != null && m.coroutine && (ma == null || ma.member_name != "begin"
				                         || ma.inner.symbol_reference != ma.symbol_reference)) {
				var cfrag = new CCodeFragment ();

				int state = next_coroutine_state++;

				cfrag.append (stmt.ccodenode);
				cfrag.append (new CCodeExpressionStatement (new CCodeAssignment (new CCodeMemberAccess.pointer (new CCodeIdentifier ("data"), "state"), new CCodeConstant (state.to_string ()))));
				cfrag.append (new CCodeReturnStatement (new CCodeConstant ("FALSE")));
				cfrag.append (new CCodeCaseStatement (new CCodeConstant (state.to_string ())));

				stmt.ccodenode = cfrag;
			}
		}

		if (stmt.tree_can_fail && stmt.expression.tree_can_fail) {
			// simple case, no node breakdown necessary

			var cfrag = new CCodeFragment ();

			cfrag.append (stmt.ccodenode);

			add_simple_check (stmt.expression, cfrag);

			stmt.ccodenode = cfrag;
		}

		/* free temporary objects */

		if (((Gee.List<LocalVariable>) temp_vars).size == 0) {
			/* nothing to do without temporary variables */
			return;
		}
		
		var cfrag = new CCodeFragment ();
		append_temp_decl (cfrag, temp_vars);
		
		cfrag.append (stmt.ccodenode);
		
		foreach (LocalVariable local in temp_ref_vars) {
			var ma = new MemberAccess.simple (local.name);
			ma.symbol_reference = local;
			cfrag.append (new CCodeExpressionStatement (get_unref_expression (new CCodeIdentifier (local.name), local.variable_type, ma)));
		}
		
		stmt.ccodenode = cfrag;
		
		temp_vars.clear ();
		temp_ref_vars.clear ();
	}
	
	private void create_temp_decl (Statement stmt, Gee.List<LocalVariable> temp_vars) {
		/* declare temporary variables */
		
		if (temp_vars.size == 0) {
			/* nothing to do without temporary variables */
			return;
		}
		
		var cfrag = new CCodeFragment ();
		append_temp_decl (cfrag, temp_vars);
		
		// FIXME cast to CodeNode shouldn't be necessary as Statement requires CodeNode
		cfrag.append (((CodeNode) stmt).ccodenode);
		
		((CodeNode) stmt).ccodenode = cfrag;
	}

	public override void visit_if_statement (IfStatement stmt) {
		stmt.accept_children (this);

		if (stmt.false_statement != null) {
			stmt.ccodenode = new CCodeIfStatement ((CCodeExpression) stmt.condition.ccodenode, (CCodeStatement) stmt.true_statement.ccodenode, (CCodeStatement) stmt.false_statement.ccodenode);
		} else {
			stmt.ccodenode = new CCodeIfStatement ((CCodeExpression) stmt.condition.ccodenode, (CCodeStatement) stmt.true_statement.ccodenode);
		}
		
		create_temp_decl (stmt, stmt.condition.temp_vars);
	}

	void visit_string_switch_statement (SwitchStatement stmt) {
		// we need a temporary variable to save the property value
		var temp_var = get_temp_variable (stmt.expression.value_type, true, stmt);
		stmt.expression.temp_vars.insert (0, temp_var);

		var ctemp = new CCodeIdentifier (temp_var.name);
		var cinit = new CCodeAssignment (ctemp, (CCodeExpression) stmt.expression.ccodenode);
		var czero = new CCodeConstant ("0");

		var cswitchblock = new CCodeFragment ();
		stmt.ccodenode = cswitchblock;

		var cisnull = new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, new CCodeConstant ("NULL"), ctemp);
		var cquark = new CCodeFunctionCall (new CCodeIdentifier ("g_quark_from_string"));
		cquark.add_argument (ctemp);

		var ccond = new CCodeConditionalExpression (cisnull, new CCodeConstant ("0"), cquark);

		temp_var = get_temp_variable (gquark_type);
		stmt.expression.temp_vars.insert (0, temp_var);

		int label_count = 0;

		foreach (SwitchSection section in stmt.get_sections ()) {
			if (section.has_default_label ()) {
				continue;
			}

			foreach (SwitchLabel label in section.get_labels ()) {
				var cexpr = (CCodeExpression) label.expression.ccodenode;

				if (is_constant_ccode_expression (cexpr)) {
					var cname = "%s_label%d".printf (temp_var.name, label_count++);
					var cdecl = new CCodeDeclaration (gquark_type.get_cname ());

					cdecl.modifiers = CCodeModifiers.STATIC;
					cdecl.add_declarator (new CCodeVariableDeclarator.with_initializer (cname, czero));

					cswitchblock.append (cdecl);
				}
			}
		}

		cswitchblock.append (new CCodeExpressionStatement (cinit));

		ctemp = new CCodeIdentifier (temp_var.name);
		cinit = new CCodeAssignment (ctemp, ccond);

		cswitchblock.append (new CCodeExpressionStatement (cinit));
		create_temp_decl (stmt, stmt.expression.temp_vars);

		Gee.List<Statement> default_statements = null;
		label_count = 0;

		// generate nested if statements		
		CCodeStatement ctopstmt = null;
		CCodeIfStatement coldif = null;

		foreach (SwitchSection section in stmt.get_sections ()) {
			if (section.has_default_label ()) {
				default_statements = section.get_statements ();
				continue;
			}

			CCodeBinaryExpression cor = null;
			foreach (SwitchLabel label in section.get_labels ()) {
				var cexpr = (CCodeExpression) label.expression.ccodenode;

				if (is_constant_ccode_expression (cexpr)) {
					var cname = new CCodeIdentifier ("%s_label%d".printf (temp_var.name, label_count++));
					var ccond = new CCodeBinaryExpression (CCodeBinaryOperator.INEQUALITY, czero, cname);
					var ccall = new CCodeFunctionCall (new CCodeIdentifier ("g_quark_from_static_string"));
					var cinit = new CCodeParenthesizedExpression (new CCodeAssignment (cname, ccall));

					ccall.add_argument (cexpr);

					cexpr = new CCodeConditionalExpression (ccond, cname, cinit);
				} else {
					var ccall = new CCodeFunctionCall (new CCodeIdentifier ("g_quark_from_string"));
					ccall.add_argument (cexpr);
					cexpr = ccall;
				}

				var ccmp = new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, ctemp, cexpr);

				if (cor == null) {
					cor = ccmp;
				} else {
					cor = new CCodeBinaryExpression (CCodeBinaryOperator.OR, cor, ccmp);
				}
			}

			var cblock = new CCodeBlock ();
			foreach (CodeNode body_stmt in section.get_statements ()) {
				if (body_stmt.ccodenode is CCodeFragment) {
					foreach (CCodeNode cstmt in ((CCodeFragment) body_stmt.ccodenode).get_children ()) {
						cblock.add_statement (cstmt);
					}
				} else {
					cblock.add_statement (body_stmt.ccodenode);
				}
			}

			var cdo = new CCodeDoStatement (cblock, new CCodeConstant ("0"));
			var cif = new CCodeIfStatement (cor, cdo);

			if (coldif != null) {
				coldif.false_statement = cif;
			} else {
				ctopstmt = cif;
			}

			coldif = cif;
		}
	
		if (default_statements != null) {
			var cblock = new CCodeBlock ();
			foreach (CodeNode body_stmt in default_statements) {
				cblock.add_statement (body_stmt.ccodenode);
			}
		
			var cdo = new CCodeDoStatement (cblock, new CCodeConstant ("0"));

			if (coldif == null) {
				// there is only one section and that section
				// contains a default label
				ctopstmt = cdo;
			} else {
				coldif.false_statement = cdo;
			}
		}
	
		cswitchblock.append (ctopstmt);
	}

	public override void visit_switch_statement (SwitchStatement stmt) {
		if (stmt.expression.value_type.compatible (string_type)) {
			visit_string_switch_statement (stmt);
			return;
		}

		var cswitch = new CCodeSwitchStatement ((CCodeExpression) stmt.expression.ccodenode);
		stmt.ccodenode = cswitch;

		foreach (SwitchSection section in stmt.get_sections ()) {
			if (section.has_default_label ()) {
				cswitch.add_statement (new CCodeLabel ("default"));
				var cdefaultblock = new CCodeBlock ();
				cswitch.add_statement (cdefaultblock);
				foreach (CodeNode default_stmt in section.get_statements ()) {
					cdefaultblock.add_statement (default_stmt.ccodenode);
				}
				continue;
			}

			foreach (SwitchLabel label in section.get_labels ()) {
				cswitch.add_statement (new CCodeCaseStatement ((CCodeExpression) label.expression.ccodenode));
			}

			var cblock = new CCodeBlock ();
			cswitch.add_statement (cblock);
			foreach (CodeNode body_stmt in section.get_statements ()) {
				cblock.add_statement (body_stmt.ccodenode);
			}
		}
	}

	public override void visit_switch_section (SwitchSection section) {
		visit_block (section);
	}

	public override void visit_while_statement (WhileStatement stmt) {
		stmt.accept_children (this);

		stmt.ccodenode = new CCodeWhileStatement ((CCodeExpression) stmt.condition.ccodenode, (CCodeStatement) stmt.body.ccodenode);
		
		create_temp_decl (stmt, stmt.condition.temp_vars);
	}

	public override void visit_do_statement (DoStatement stmt) {
		stmt.accept_children (this);

		stmt.ccodenode = new CCodeDoStatement ((CCodeStatement) stmt.body.ccodenode, (CCodeExpression) stmt.condition.ccodenode);
		
		create_temp_decl (stmt, stmt.condition.temp_vars);
	}

	public override void visit_for_statement (ForStatement stmt) {
		stmt.accept_children (this);

		CCodeExpression ccondition = null;
		if (stmt.condition != null) {
			ccondition = (CCodeExpression) stmt.condition.ccodenode;
		}

		var cfor = new CCodeForStatement (ccondition, (CCodeStatement) stmt.body.ccodenode);
		stmt.ccodenode = cfor;
		
		foreach (Expression init_expr in stmt.get_initializer ()) {
			cfor.add_initializer ((CCodeExpression) init_expr.ccodenode);
			create_temp_decl (stmt, init_expr.temp_vars);
		}
		
		foreach (Expression it_expr in stmt.get_iterator ()) {
			cfor.add_iterator ((CCodeExpression) it_expr.ccodenode);
			create_temp_decl (stmt, it_expr.temp_vars);
		}

		if (stmt.condition != null) {
			create_temp_decl (stmt, stmt.condition.temp_vars);
		}
	}

	public override void visit_foreach_statement (ForeachStatement stmt) {
		stmt.element_variable.active = true;
		stmt.collection_variable.active = true;
		if (stmt.iterator_variable != null) {
			stmt.iterator_variable.active = true;
		}

		visit_block (stmt);

		var cblock = new CCodeBlock ();
		// sets #line
		stmt.ccodenode = cblock;

		var cfrag = new CCodeFragment ();
		append_temp_decl (cfrag, stmt.collection.temp_vars);
		cblock.add_statement (cfrag);
		
		var collection_backup = stmt.collection_variable;
		var collection_type = collection_backup.variable_type.copy ();
		var ccoldecl = new CCodeDeclaration (collection_type.get_cname ());
		var ccolvardecl = new CCodeVariableDeclarator.with_initializer (collection_backup.name, (CCodeExpression) stmt.collection.ccodenode);
		ccolvardecl.line = cblock.line;
		ccoldecl.add_declarator (ccolvardecl);
		cblock.add_statement (ccoldecl);
		
		if (stmt.tree_can_fail && stmt.collection.tree_can_fail) {
			// exception handling
			var cfrag = new CCodeFragment ();
			add_simple_check (stmt.collection, cfrag);
			cblock.add_statement (cfrag);
		}

		if (stmt.collection.value_type is ArrayType) {
			var array_type = (ArrayType) stmt.collection.value_type;
			
			var array_len = head.get_array_length_cexpression (stmt.collection);

			// store array length for use by _vala_array_free
			var clendecl = new CCodeDeclaration ("int");
			clendecl.add_declarator (new CCodeVariableDeclarator.with_initializer (head.get_array_length_cname (collection_backup.name, 1), array_len));
			cblock.add_statement (clendecl);

			if (array_len is CCodeConstant) {
				// the array has no length parameter i.e. it is NULL-terminated array

				var it_name = "%s_it".printf (stmt.variable_name);
			
				var citdecl = new CCodeDeclaration (collection_type.get_cname ());
				citdecl.add_declarator (new CCodeVariableDeclarator (it_name));
				cblock.add_statement (citdecl);
				
				var cbody = new CCodeBlock ();

				CCodeExpression element_expr = new CCodeIdentifier ("*%s".printf (it_name));

				var element_type = array_type.element_type.copy ();
				element_type.value_owned = false;
				element_expr = transform_expression (element_expr, element_type, stmt.type_reference);

				var cfrag = new CCodeFragment ();
				append_temp_decl (cfrag, temp_vars);
				cbody.add_statement (cfrag);
				temp_vars.clear ();

				var cdecl = new CCodeDeclaration (stmt.type_reference.get_cname ());
				cdecl.add_declarator (new CCodeVariableDeclarator.with_initializer (stmt.variable_name, element_expr));
				cbody.add_statement (cdecl);

				// add array length variable for stacked arrays
				if (stmt.type_reference is ArrayType) {
					var inner_array_type = (ArrayType) stmt.type_reference;
					for (int dim = 1; dim <= inner_array_type.rank; dim++) {
						cdecl = new CCodeDeclaration ("int");
						cdecl.add_declarator (new CCodeVariableDeclarator.with_initializer (head.get_array_length_cname (stmt.variable_name, dim), new CCodeConstant ("-1")));
						cbody.add_statement (cdecl);
					}
				}

				cbody.add_statement (stmt.body.ccodenode);
				
				var ccond = new CCodeBinaryExpression (CCodeBinaryOperator.INEQUALITY, new CCodeIdentifier ("*%s".printf (it_name)), new CCodeConstant ("NULL"));
				
				var cfor = new CCodeForStatement (ccond, cbody);

				cfor.add_initializer (new CCodeAssignment (new CCodeIdentifier (it_name), new CCodeIdentifier (collection_backup.name)));
		
				cfor.add_iterator (new CCodeAssignment (new CCodeIdentifier (it_name), new CCodeBinaryExpression (CCodeBinaryOperator.PLUS, new CCodeIdentifier (it_name), new CCodeConstant ("1"))));
				cblock.add_statement (cfor);
			} else {
				// the array has a length parameter

				var it_name = (stmt.variable_name + "_it");
			
				var citdecl = new CCodeDeclaration ("int");
				citdecl.add_declarator (new CCodeVariableDeclarator (it_name));
				cblock.add_statement (citdecl);
				
				var cbody = new CCodeBlock ();

				CCodeExpression element_expr = new CCodeElementAccess (new CCodeIdentifier (collection_backup.name), new CCodeIdentifier (it_name));

				var element_type = array_type.element_type.copy ();
				element_type.value_owned = false;
				element_expr = transform_expression (element_expr, element_type, stmt.type_reference);

				var cfrag = new CCodeFragment ();
				append_temp_decl (cfrag, temp_vars);
				cbody.add_statement (cfrag);
				temp_vars.clear ();

				var cdecl = new CCodeDeclaration (stmt.type_reference.get_cname ());
				cdecl.add_declarator (new CCodeVariableDeclarator.with_initializer (stmt.variable_name, element_expr));
				cbody.add_statement (cdecl);

				// add array length variable for stacked arrays
				if (stmt.type_reference is ArrayType) {
					var inner_array_type = (ArrayType) stmt.type_reference;
					for (int dim = 1; dim <= inner_array_type.rank; dim++) {
						cdecl = new CCodeDeclaration ("int");
						cdecl.add_declarator (new CCodeVariableDeclarator.with_initializer (head.get_array_length_cname (stmt.variable_name, dim), new CCodeConstant ("-1")));
						cbody.add_statement (cdecl);
					}
				}

				cbody.add_statement (stmt.body.ccodenode);
				
				var ccond_ind1 = new CCodeBinaryExpression (CCodeBinaryOperator.INEQUALITY, array_len, new CCodeConstant ("-1"));
				var ccond_ind2 = new CCodeBinaryExpression (CCodeBinaryOperator.LESS_THAN, new CCodeIdentifier (it_name), array_len);
				var ccond_ind = new CCodeBinaryExpression (CCodeBinaryOperator.AND, ccond_ind1, ccond_ind2);
				
				/* only check for null if the containers elements are of reference-type */
				CCodeBinaryExpression ccond;
				if (array_type.element_type.is_reference_type_or_type_parameter ()) {
					var ccond_term1 = new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, array_len, new CCodeConstant ("-1"));
					var ccond_term2 = new CCodeBinaryExpression (CCodeBinaryOperator.INEQUALITY, new CCodeElementAccess (new CCodeIdentifier (collection_backup.name), new CCodeIdentifier (it_name)), new CCodeConstant ("NULL"));
					var ccond_term = new CCodeBinaryExpression (CCodeBinaryOperator.AND, ccond_term1, ccond_term2);

					ccond = new CCodeBinaryExpression (CCodeBinaryOperator.OR, new CCodeParenthesizedExpression (ccond_ind), new CCodeParenthesizedExpression (ccond_term));
				} else {
					/* assert when trying to iterate over value-type arrays of unknown length */
					var cassert = new CCodeFunctionCall (new CCodeIdentifier ("g_assert"));
					cassert.add_argument (ccond_ind1);
					cblock.add_statement (new CCodeExpressionStatement (cassert));

					ccond = ccond_ind2;
				}
				
				var cfor = new CCodeForStatement (ccond, cbody);
				cfor.add_initializer (new CCodeAssignment (new CCodeIdentifier (it_name), new CCodeConstant ("0")));
				cfor.add_iterator (new CCodeAssignment (new CCodeIdentifier (it_name), new CCodeBinaryExpression (CCodeBinaryOperator.PLUS, new CCodeIdentifier (it_name), new CCodeConstant ("1"))));
				cblock.add_statement (cfor);
			}
		} else if (stmt.collection.value_type.compatible (new ObjectType (glist_type)) || stmt.collection.value_type.compatible (new ObjectType (gslist_type))) {
			// iterating over a GList or GSList

			var it_name = "%s_it".printf (stmt.variable_name);
		
			var citdecl = new CCodeDeclaration (collection_type.get_cname ());
			var citvardecl = new CCodeVariableDeclarator (it_name);
			citvardecl.line = cblock.line;
			citdecl.add_declarator (citvardecl);
			cblock.add_statement (citdecl);
			
			var cbody = new CCodeBlock ();

			CCodeExpression element_expr = new CCodeMemberAccess.pointer (new CCodeIdentifier (it_name), "data");

			if (collection_type.get_type_arguments ().size != 1) {
				Report.error (stmt.source_reference, "internal error: missing generic type argument");
				stmt.error = true;
				return;
			}

			var element_data_type = collection_type.get_type_arguments ().get (0).copy ();
			element_data_type.value_owned = false;
			element_data_type.is_type_argument = true;
			element_expr = transform_expression (element_expr, element_data_type, stmt.type_reference);

			var cfrag = new CCodeFragment ();
			append_temp_decl (cfrag, temp_vars);
			cbody.add_statement (cfrag);
			temp_vars.clear ();

			var cdecl = new CCodeDeclaration (stmt.type_reference.get_cname ());
			var cvardecl = new CCodeVariableDeclarator.with_initializer (stmt.variable_name, element_expr);
			cvardecl.line = cblock.line;
			cdecl.add_declarator (cvardecl);
			cbody.add_statement (cdecl);
			
			cbody.add_statement (stmt.body.ccodenode);
			
			var ccond = new CCodeBinaryExpression (CCodeBinaryOperator.INEQUALITY, new CCodeIdentifier (it_name), new CCodeConstant ("NULL"));
			
			var cfor = new CCodeForStatement (ccond, cbody);
			
			cfor.add_initializer (new CCodeAssignment (new CCodeIdentifier (it_name), new CCodeIdentifier (collection_backup.name)));

			cfor.add_iterator (new CCodeAssignment (new CCodeIdentifier (it_name), new CCodeMemberAccess.pointer (new CCodeIdentifier (it_name), "next")));
			cblock.add_statement (cfor);
		} else if (list_type != null && stmt.collection.value_type.compatible (new ObjectType (list_type))) {
			// iterating over a Gee.List, use integer to avoid the cost of an iterator object

			var it_name = "%s_it".printf (stmt.variable_name);

			var citdecl = new CCodeDeclaration ("int");
			citdecl.add_declarator (new CCodeVariableDeclarator (it_name));
			cblock.add_statement (citdecl);
			
			var cbody = new CCodeBlock ();

			var get_method = (Method) list_type.scope.lookup ("get");
			var get_ccall = new CCodeFunctionCall (new CCodeIdentifier (get_method.get_cname ()));
			get_ccall.add_argument (new InstanceCast (new CCodeIdentifier (collection_backup.name), list_type));
			get_ccall.add_argument (new CCodeIdentifier (it_name));
			CCodeExpression element_expr = get_ccall;

			var element_type = SemanticAnalyzer.get_actual_type (stmt.collection.value_type, get_method, get_method.return_type, stmt);

			element_expr = transform_expression (element_expr, element_type, stmt.type_reference);

			var cfrag = new CCodeFragment ();
			append_temp_decl (cfrag, temp_vars);
			cbody.add_statement (cfrag);
			temp_vars.clear ();

			var cdecl = new CCodeDeclaration (stmt.type_reference.get_cname ());
			var cvardecl = new CCodeVariableDeclarator.with_initializer (stmt.variable_name, element_expr);
			cvardecl.line = cblock.line;
			cdecl.add_declarator (cvardecl);
			cbody.add_statement (cdecl);

			cbody.add_statement (stmt.body.ccodenode);

			var list_len = new CCodeFunctionCall (new CCodeIdentifier ("gee_collection_get_size"));
			list_len.add_argument (new InstanceCast (new CCodeIdentifier (collection_backup.name), this.collection_type));

			var ccond = new CCodeBinaryExpression (CCodeBinaryOperator.LESS_THAN, new CCodeIdentifier (it_name), list_len);

			var cfor = new CCodeForStatement (ccond, cbody);
			cfor.add_initializer (new CCodeAssignment (new CCodeIdentifier (it_name), new CCodeConstant ("0")));
			cfor.add_iterator (new CCodeAssignment (new CCodeIdentifier (it_name), new CCodeBinaryExpression (CCodeBinaryOperator.PLUS, new CCodeIdentifier (it_name), new CCodeConstant ("1"))));
			cfor.line = cblock.line;
			cblock.add_statement (cfor);
		} else if (iterable_type != null && stmt.collection.value_type.compatible (new ObjectType (iterable_type))) {
			// iterating over a Gee.Iterable, use iterator

			var it_name = "%s_it".printf (stmt.variable_name);

			var citdecl = new CCodeDeclaration (iterator_type.get_cname () + "*");
			var it_method = (Method) iterable_type.scope.lookup ("iterator");
			var it_ccall = new CCodeFunctionCall (new CCodeIdentifier (it_method.get_cname ()));
			it_ccall.add_argument (new InstanceCast (new CCodeIdentifier (collection_backup.name), iterable_type));
			var citvardecl = new CCodeVariableDeclarator.with_initializer (it_name, it_ccall);
			citvardecl.line = cblock.line;
			citdecl.add_declarator (citvardecl);
			cblock.add_statement (citdecl);
			
			var cbody = new CCodeBlock ();

			var get_method = (Method) iterator_type.scope.lookup ("get");
			var get_ccall = new CCodeFunctionCall (new CCodeIdentifier (get_method.get_cname ()));
			get_ccall.add_argument (new CCodeIdentifier (it_name));
			CCodeExpression element_expr = get_ccall;

			Iterator<DataType> type_arg_it = it_method.return_type.get_type_arguments ().iterator ();
			type_arg_it.next ();
			var it_type = SemanticAnalyzer.get_actual_type (stmt.collection.value_type, it_method, type_arg_it.get (), stmt);

			element_expr = transform_expression (element_expr, it_type, stmt.type_reference);

			var cfrag = new CCodeFragment ();
			append_temp_decl (cfrag, temp_vars);
			cbody.add_statement (cfrag);
			temp_vars.clear ();

			var cdecl = new CCodeDeclaration (stmt.type_reference.get_cname ());
			var cvardecl = new CCodeVariableDeclarator.with_initializer (stmt.variable_name, element_expr);
			cvardecl.line = cblock.line;
			cdecl.add_declarator (cvardecl);
			cbody.add_statement (cdecl);
			
			cbody.add_statement (stmt.body.ccodenode);

			var next_method = (Method) iterator_type.scope.lookup ("next");
			var next_ccall = new CCodeFunctionCall (new CCodeIdentifier (next_method.get_cname ()));
			next_ccall.add_argument (new CCodeIdentifier (it_name));

			var cwhile = new CCodeWhileStatement (next_ccall, cbody);
			cwhile.line = cblock.line;
			cblock.add_statement (cwhile);
		}

		foreach (LocalVariable local in stmt.get_local_variables ()) {
			if (requires_destroy (local.variable_type)) {
				var ma = new MemberAccess.simple (local.name);
				ma.symbol_reference = local;
				var cunref = new CCodeExpressionStatement (get_unref_expression (new CCodeIdentifier (get_variable_cname (local.name)), local.variable_type, ma));
				cunref.line = cblock.line;
				cblock.add_statement (cunref);
			}
		}
	}

	public override void visit_break_statement (BreakStatement stmt) {
		stmt.ccodenode = new CCodeBreakStatement ();

		create_local_free (stmt, true);
	}

	public override void visit_continue_statement (ContinueStatement stmt) {
		stmt.ccodenode = new CCodeContinueStatement ();

		create_local_free (stmt, true);
	}

	private void append_local_free (Symbol sym, CCodeFragment cfrag, bool stop_at_loop) {
		var b = (Block) sym;

		var local_vars = b.get_local_variables ();
		foreach (LocalVariable local in local_vars) {
			if (local.active && requires_destroy (local.variable_type)) {
				var ma = new MemberAccess.simple (local.name);
				ma.symbol_reference = local;
				cfrag.append (new CCodeExpressionStatement (get_unref_expression (new CCodeIdentifier (get_variable_cname (local.name)), local.variable_type, ma)));
			}
		}
		
		if (stop_at_loop) {
			if (b.parent_node is DoStatement || b.parent_node is WhileStatement ||
			    b.parent_node is ForStatement || b.parent_node is ForeachStatement ||
			    b.parent_node is SwitchStatement) {
				return;
			}
		}

		if (sym.parent_symbol is Block) {
			append_local_free (sym.parent_symbol, cfrag, stop_at_loop);
		} else if (sym.parent_symbol is Method) {
			append_param_free ((Method) sym.parent_symbol, cfrag);
		}
	}

	private void append_param_free (Method m, CCodeFragment cfrag) {
		foreach (FormalParameter param in m.get_parameters ()) {
			if (requires_destroy (param.parameter_type) && param.direction == ParameterDirection.IN) {
				var ma = new MemberAccess.simple (param.name);
				ma.symbol_reference = param;
				cfrag.append (new CCodeExpressionStatement (get_unref_expression (new CCodeIdentifier (get_variable_cname (param.name)), param.parameter_type, ma)));
			}
		}
	}

	private void create_local_free (CodeNode stmt, bool stop_at_loop = false) {
		var cfrag = new CCodeFragment ();
	
		append_local_free (current_symbol, cfrag, stop_at_loop);

		cfrag.append (stmt.ccodenode);
		stmt.ccodenode = cfrag;
	}

	private bool append_local_free_expr (Symbol sym, CCodeCommaExpression ccomma, bool stop_at_loop) {
		bool found = false;
	
		var b = (Block) sym;

		var local_vars = b.get_local_variables ();
		foreach (LocalVariable local in local_vars) {
			if (local.active && requires_destroy (local.variable_type)) {
				found = true;
				var ma = new MemberAccess.simple (local.name);
				ma.symbol_reference = local;
				ccomma.append_expression (get_unref_expression (new CCodeIdentifier (get_variable_cname (local.name)), local.variable_type, ma));
			}
		}
		
		if (sym.parent_symbol is Block) {
			found = append_local_free_expr (sym.parent_symbol, ccomma, stop_at_loop) || found;
		} else if (sym.parent_symbol is Method) {
			found = append_param_free_expr ((Method) sym.parent_symbol, ccomma) || found;
		}
		
		return found;
	}

	private bool append_param_free_expr (Method m, CCodeCommaExpression ccomma) {
		bool found = false;

		foreach (FormalParameter param in m.get_parameters ()) {
			if (requires_destroy (param.parameter_type) && param.direction == ParameterDirection.IN) {
				found = true;
				var ma = new MemberAccess.simple (param.name);
				ma.symbol_reference = param;
				ccomma.append_expression (get_unref_expression (new CCodeIdentifier (get_variable_cname (param.name)), param.parameter_type, ma));
			}
		}

		return found;
	}

	private void create_local_free_expr (Expression expr) {
		var expr_type = expr.value_type;
		if (expr.target_type != null) {
			expr_type = expr.target_type;
		}

		var return_expr_decl = get_temp_variable (expr_type, true, expr);
		
		var ccomma = new CCodeCommaExpression ();
		ccomma.append_expression (new CCodeAssignment (new CCodeIdentifier (return_expr_decl.name), (CCodeExpression) expr.ccodenode));

		if (!append_local_free_expr (current_symbol, ccomma, false)) {
			/* no local variables need to be freed */
			return;
		}

		ccomma.append_expression (new CCodeIdentifier (return_expr_decl.name));
		
		expr.ccodenode = ccomma;
		expr.temp_vars.add (return_expr_decl);
	}

	public override void visit_return_statement (ReturnStatement stmt) {
		// avoid unnecessary ref/unref pair
		if (stmt.return_expression != null) {
			var local = stmt.return_expression.symbol_reference as LocalVariable;
			if (current_return_type.value_owned
			    && local != null && local.variable_type.value_owned) {
				/* return expression is local variable taking ownership and
				 * current method is transferring ownership */

				// don't ref expression
				stmt.return_expression.value_type.value_owned = true;
			}
		}

		stmt.accept_children (this);

		if (stmt.return_expression == null) {
			stmt.ccodenode = new CCodeReturnStatement ();
			
			create_local_free (stmt);
		} else {
			Symbol return_expression_symbol = null;

			// avoid unnecessary ref/unref pair
			var local = stmt.return_expression.symbol_reference as LocalVariable;
			if (current_return_type.value_owned
			    && local != null && local.variable_type.value_owned) {
				/* return expression is local variable taking ownership and
				 * current method is transferring ownership */

				// don't unref variable
				return_expression_symbol = local;
				return_expression_symbol.active = false;
			}

			// return array length if appropriate
			if (current_method != null && !current_method.no_array_length && current_return_type is ArrayType) {
				var return_expr_decl = get_temp_variable (stmt.return_expression.value_type, true, stmt);

				var ccomma = new CCodeCommaExpression ();
				ccomma.append_expression (new CCodeAssignment (new CCodeIdentifier (return_expr_decl.name), (CCodeExpression) stmt.return_expression.ccodenode));

				var array_type = (ArrayType) current_return_type;

				for (int dim = 1; dim <= array_type.rank; dim++) {
					var len_l = new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, new CCodeIdentifier (head.get_array_length_cname ("result", dim)));
					var len_r = head.get_array_length_cexpression (stmt.return_expression, dim);
					ccomma.append_expression (new CCodeAssignment (len_l, len_r));
				}

				ccomma.append_expression (new CCodeIdentifier (return_expr_decl.name));
				
				stmt.return_expression.ccodenode = ccomma;
				stmt.return_expression.temp_vars.add (return_expr_decl);
			}

			create_local_free_expr (stmt.return_expression);

			// Property getters of non simple structs shall return the struct value as out parameter,
			// therefore replace any return statement with an assignment statement to the out formal
			// paramenter and insert an empty return statement afterwards.
			if (current_property_accessor != null &&
			    current_property_accessor.readable &&
			    current_property_accessor.prop.property_type.is_real_struct_type()) {
			    	var cfragment = new CCodeFragment ();
				cfragment.append (new CCodeExpressionStatement (new CCodeAssignment (new CCodeIdentifier ("*value"), (CCodeExpression) stmt.return_expression.ccodenode)));
				cfragment.append (new CCodeReturnStatement ());
				stmt.ccodenode = cfragment;
			} else {
				stmt.ccodenode = new CCodeReturnStatement ((CCodeExpression) stmt.return_expression.ccodenode);
			}

			create_temp_decl (stmt, stmt.return_expression.temp_vars);

			if (return_expression_symbol != null) {
				return_expression_symbol.active = true;
			}
		}
	}

	public override void visit_yield_statement (YieldStatement stmt) {
		if (stmt.yield_expression == null) {
			var cfrag = new CCodeFragment ();
			stmt.ccodenode = cfrag;

			var idle_call = new CCodeFunctionCall (new CCodeIdentifier ("g_idle_add"));
			idle_call.add_argument (new CCodeCastExpression (new CCodeIdentifier (current_method.get_real_cname ()), "GSourceFunc"));
			idle_call.add_argument (new CCodeIdentifier ("data"));

			int state = next_coroutine_state++;

			cfrag.append (new CCodeExpressionStatement (idle_call));
			cfrag.append (new CCodeExpressionStatement (new CCodeAssignment (new CCodeMemberAccess.pointer (new CCodeIdentifier ("data"), "state"), new CCodeConstant (state.to_string ()))));
			cfrag.append (new CCodeReturnStatement (new CCodeConstant ("FALSE")));
			cfrag.append (new CCodeCaseStatement (new CCodeConstant (state.to_string ())));

			return;
		}

		stmt.accept_children (this);

		if (stmt.yield_expression.error) {
			stmt.error = true;
			return;
		}

		stmt.ccodenode = new CCodeExpressionStatement ((CCodeExpression) stmt.yield_expression.ccodenode);

		if (stmt.tree_can_fail && stmt.yield_expression.tree_can_fail) {
			// simple case, no node breakdown necessary

			var cfrag = new CCodeFragment ();

			cfrag.append (stmt.ccodenode);

			add_simple_check (stmt.yield_expression, cfrag);

			stmt.ccodenode = cfrag;
		}

		/* free temporary objects */

		if (((Gee.List<LocalVariable>) temp_vars).size == 0) {
			/* nothing to do without temporary variables */
			return;
		}
		
		var cfrag = new CCodeFragment ();
		append_temp_decl (cfrag, temp_vars);
		
		cfrag.append (stmt.ccodenode);
		
		foreach (LocalVariable local in temp_ref_vars) {
			var ma = new MemberAccess.simple (local.name);
			ma.symbol_reference = local;
			cfrag.append (new CCodeExpressionStatement (get_unref_expression (new CCodeIdentifier (local.name), local.variable_type, ma)));
		}
		
		stmt.ccodenode = cfrag;
		
		temp_vars.clear ();
		temp_ref_vars.clear ();
	}

	public override void visit_throw_statement (ThrowStatement stmt) {
		stmt.accept_children (this);

		var cfrag = new CCodeFragment ();

		// method will fail
		current_method_inner_error = true;
		var cassign = new CCodeAssignment (new CCodeIdentifier ("inner_error"), (CCodeExpression) stmt.error_expression.ccodenode);
		cfrag.append (new CCodeExpressionStatement (cassign));

		add_simple_check (stmt, cfrag);

		stmt.ccodenode = cfrag;

		create_temp_decl (stmt, stmt.error_expression.temp_vars);
	}

	public override void visit_try_statement (TryStatement stmt) {
		int this_try_id = next_try_id++;

		var old_try = current_try;
		var old_try_id = current_try_id;
		current_try = stmt;
		current_try_id = this_try_id;

		foreach (CatchClause clause in stmt.get_catch_clauses ()) {
			clause.clabel_name = "__catch%d_%s".printf (this_try_id, clause.error_type.get_lower_case_cname ());
		}

		if (stmt.finally_body != null) {
			stmt.finally_body.accept (this);
		}

		stmt.body.accept (this);

		current_try = old_try;
		current_try_id = old_try_id;

		foreach (CatchClause clause in stmt.get_catch_clauses ()) {
			clause.accept (this);
		}

		if (stmt.finally_body != null) {
			stmt.finally_body.accept (this);
		}

		var cfrag = new CCodeFragment ();
		cfrag.append (stmt.body.ccodenode);

		foreach (CatchClause clause in stmt.get_catch_clauses ()) {
			cfrag.append (new CCodeGotoStatement ("__finally%d".printf (this_try_id)));

			cfrag.append (clause.ccodenode);
		}

		cfrag.append (new CCodeLabel ("__finally%d".printf (this_try_id)));
		if (stmt.finally_body != null) {
			cfrag.append (stmt.finally_body.ccodenode);
		} else {
			// avoid gcc error: label at end of compound statement
			cfrag.append (new CCodeEmptyStatement ());
		}

		stmt.ccodenode = cfrag;
	}

	public override void visit_catch_clause (CatchClause clause) {
		if (clause.error_variable != null) {
			clause.error_variable.active = true;
		}

		current_method_inner_error = true;

		clause.accept_children (this);

		var cfrag = new CCodeFragment ();
		cfrag.append (new CCodeLabel (clause.clabel_name));

		var cblock = new CCodeBlock ();

		string variable_name = clause.variable_name;
		if (variable_name == null) {
			variable_name = "__err";
		}

		var cdecl = new CCodeDeclaration ("GError *");
		cdecl.add_declarator (new CCodeVariableDeclarator.with_initializer (variable_name, new CCodeIdentifier ("inner_error")));
		cblock.add_statement (cdecl);
		cblock.add_statement (new CCodeExpressionStatement (new CCodeAssignment (new CCodeIdentifier ("inner_error"), new CCodeConstant ("NULL"))));

		cblock.add_statement (clause.body.ccodenode);

		cfrag.append (cblock);

		clause.ccodenode = cfrag;
	}

	private string get_symbol_lock_name (Symbol sym) {
		return "__lock_%s".printf (sym.name);
	}

	public override void visit_lock_statement (LockStatement stmt) {
		var cn = new CCodeFragment ();
		CCodeExpression l = null;
		CCodeFunctionCall fc;
		var inner_node = ((MemberAccess)stmt.resource).inner;
		
		if (inner_node  == null) {
			l = new CCodeIdentifier ("self");
		} else if (stmt.resource.symbol_reference.parent_symbol != current_type_symbol) {
			 l = new InstanceCast ((CCodeExpression) inner_node.ccodenode, (TypeSymbol) stmt.resource.symbol_reference.parent_symbol);
		} else {
			l = (CCodeExpression) inner_node.ccodenode;
		}
		l = new CCodeMemberAccess.pointer (new CCodeMemberAccess.pointer (l, "priv"), get_symbol_lock_name (stmt.resource.symbol_reference));
		
		fc = new CCodeFunctionCall (new CCodeIdentifier (((Method) mutex_type.scope.lookup ("lock")).get_cname ()));
		fc.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, l));

		cn.append (new CCodeExpressionStatement (fc));
		
		cn.append (stmt.body.ccodenode);
		
		fc = new CCodeFunctionCall (new CCodeIdentifier (((Method) mutex_type.scope.lookup ("unlock")).get_cname ()));
		fc.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, l));
		cn.append (new CCodeExpressionStatement (fc));
		
		stmt.ccodenode = cn;
	}

	public override void visit_delete_statement (DeleteStatement stmt) {
		stmt.accept_children (this);

		var pointer_type = (PointerType) stmt.expression.value_type;
		DataType type = pointer_type;
		if (pointer_type.base_type.data_type != null && pointer_type.base_type.data_type.is_reference_type ()) {
			type = pointer_type.base_type;
		}

		var ccall = new CCodeFunctionCall (get_destroy_func_expression (type));
		ccall.add_argument ((CCodeExpression) stmt.expression.ccodenode);
		stmt.ccodenode = new CCodeExpressionStatement (ccall);
	}

	public override void visit_expression (Expression expr) {
		if (expr.ccodenode != null && !expr.lvalue) {
			// memory management, implicit casts, and boxing/unboxing
			expr.ccodenode = transform_expression ((CCodeExpression) expr.ccodenode, expr.value_type, expr.target_type, expr);
		}
	}

	public override void visit_array_creation_expression (ArrayCreationExpression expr) {
		head.visit_array_creation_expression (expr);
	}

	public override void visit_boolean_literal (BooleanLiteral expr) {
		expr.ccodenode = new CCodeConstant (expr.value ? "TRUE" : "FALSE");
	}

	public override void visit_character_literal (CharacterLiteral expr) {
		if (expr.get_char () >= 0x20 && expr.get_char () < 0x80) {
			expr.ccodenode = new CCodeConstant (expr.value);
		} else {
			expr.ccodenode = new CCodeConstant ("%uU".printf (expr.get_char ()));
		}
	}

	public override void visit_integer_literal (IntegerLiteral expr) {
		expr.ccodenode = new CCodeConstant (expr.value);
	}

	public override void visit_real_literal (RealLiteral expr) {
		expr.ccodenode = new CCodeConstant (expr.value);
	}

	public override void visit_string_literal (StringLiteral expr) {
		expr.ccodenode = new CCodeConstant (expr.value);
	}

	public override void visit_null_literal (NullLiteral expr) {
		expr.ccodenode = new CCodeConstant ("NULL");
	}

	public override void visit_parenthesized_expression (ParenthesizedExpression expr) {
		expr.accept_children (this);

		expr.ccodenode = new CCodeParenthesizedExpression ((CCodeExpression) expr.inner.ccodenode);
	}

	public override void visit_member_access (MemberAccess expr) {
		head.visit_member_access (expr);
	}

	public override void visit_invocation_expression (InvocationExpression expr) {
		head.visit_invocation_expression (expr);
	}
	
	public string get_delegate_target_cname (string delegate_cname) {
		return "%s_target".printf (delegate_cname);
	}

	public CCodeExpression get_delegate_target_cexpression (Expression delegate_expr) {
		bool is_out = false;
	
		if (delegate_expr is UnaryExpression) {
			var unary_expr = (UnaryExpression) delegate_expr;
			if (unary_expr.operator == UnaryOperator.OUT || unary_expr.operator == UnaryOperator.REF) {
				delegate_expr = unary_expr.inner;
				is_out = true;
			}
		}
		
		if (delegate_expr is InvocationExpression) {
			var invocation_expr = (InvocationExpression) delegate_expr;
			return invocation_expr.delegate_target;
		} else if (delegate_expr is LambdaExpression) {
			if ((current_method != null && current_method.binding == MemberBinding.INSTANCE) || in_constructor) {
				return new CCodeIdentifier ("self");
			} else {
				return new CCodeConstant ("NULL");
			}
		} else if (delegate_expr.symbol_reference != null) {
			if (delegate_expr.symbol_reference is FormalParameter) {
				var param = (FormalParameter) delegate_expr.symbol_reference;
				CCodeExpression target_expr = new CCodeIdentifier (get_delegate_target_cname (param.name));
				if (param.direction != ParameterDirection.IN) {
					// accessing argument of out/ref param
					target_expr = new CCodeParenthesizedExpression (new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, target_expr));
				}
				if (is_out) {
					// passing array as out/ref
					return new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, target_expr);
				} else {
					return target_expr;
				}
			} else if (delegate_expr.symbol_reference is LocalVariable) {
				var local = (LocalVariable) delegate_expr.symbol_reference;
				var target_expr = new CCodeIdentifier (get_delegate_target_cname (local.name));
				if (is_out) {
					return new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, target_expr);
				} else {
					return target_expr;
				}
			} else if (delegate_expr.symbol_reference is Field) {
				var field = (Field) delegate_expr.symbol_reference;
				var target_cname = get_delegate_target_cname (field.name);

				var ma = (MemberAccess) delegate_expr;

				var base_type = ma.inner.value_type;
				CCodeExpression target_expr = null;

				var pub_inst = (CCodeExpression) get_ccodenode (ma.inner);

				if (field.binding == MemberBinding.INSTANCE) {
					var instance_expression_type = base_type;
					var instance_target_type = get_data_type_for_symbol ((TypeSymbol) field.parent_symbol);
					CCodeExpression typed_inst = transform_expression (pub_inst, instance_expression_type, instance_target_type);

					CCodeExpression inst;
					if (field.access == SymbolAccessibility.PRIVATE) {
						inst = new CCodeMemberAccess.pointer (typed_inst, "priv");
					} else {
						inst = typed_inst;
					}
					if (((TypeSymbol) field.parent_symbol).is_reference_type ()) {
						target_expr = new CCodeMemberAccess.pointer (inst, target_cname);
					} else {
						target_expr = new CCodeMemberAccess (inst, target_cname);
					}
				} else {
					target_expr = new CCodeIdentifier (target_cname);
				}

				if (is_out) {
					return new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, target_expr);
				} else {
					return target_expr;
				}
			} else if (delegate_expr.symbol_reference is Method) {
				var m = (Method) delegate_expr.symbol_reference;
				var ma = (MemberAccess) delegate_expr;
				if (m.binding == MemberBinding.STATIC) {
					return new CCodeConstant ("NULL");
				} else {
					return (CCodeExpression) get_ccodenode (ma.inner);
				}
			}
		}

		return new CCodeConstant ("NULL");
	}

	public string get_delegate_target_destroy_notify_cname (string delegate_cname) {
		return "%s_target_destroy_notify".printf (delegate_cname);
	}

	public override void visit_element_access (ElementAccess expr) {
		head.visit_element_access (expr);
	}

	public override void visit_base_access (BaseAccess expr) {
		expr.ccodenode = new InstanceCast (new CCodeIdentifier ("self"), expr.value_type.data_type);
	}

	public override void visit_postfix_expression (PostfixExpression expr) {
		MemberAccess ma = find_property_access (expr.inner);
		if (ma != null) {
			// property postfix expression
			var prop = (Property) ma.symbol_reference;
			
			var ccomma = new CCodeCommaExpression ();
			
			// assign current value to temp variable
			var temp_decl = get_temp_variable (prop.property_type, true, expr);
			temp_vars.insert (0, temp_decl);
			ccomma.append_expression (new CCodeAssignment (new CCodeIdentifier (temp_decl.name), (CCodeExpression) expr.inner.ccodenode));
			
			// increment/decrement property
			var op = expr.increment ? CCodeBinaryOperator.PLUS : CCodeBinaryOperator.MINUS;
			var cexpr = new CCodeBinaryExpression (op, new CCodeIdentifier (temp_decl.name), new CCodeConstant ("1"));
			var ccall = get_property_set_call (prop, ma, cexpr);
			ccomma.append_expression (ccall);
			
			// return previous value
			ccomma.append_expression (new CCodeIdentifier (temp_decl.name));
			
			expr.ccodenode = ccomma;
			return;
		}
	
		var op = expr.increment ? CCodeUnaryOperator.POSTFIX_INCREMENT : CCodeUnaryOperator.POSTFIX_DECREMENT;
	
		expr.ccodenode = new CCodeUnaryExpression (op, (CCodeExpression) expr.inner.ccodenode);
	}
	
	private MemberAccess? find_property_access (Expression expr) {
		if (expr is ParenthesizedExpression) {
			var pe = (ParenthesizedExpression) expr;
			return find_property_access (pe.inner);
		}
	
		if (!(expr is MemberAccess)) {
			return null;
		}
		
		var ma = (MemberAccess) expr;
		if (ma.symbol_reference is Property) {
			return ma;
		}
		
		return null;
	}

	public bool requires_copy (DataType type) {
		if (!type.is_disposable ()) {
			return false;
		}

		if (type.type_parameter != null) {
			if (!(current_type_symbol is Class) || current_class.is_compact) {
				return false;
			}
		}

		return true;
	}

	public bool requires_destroy (DataType type) {
		if (!type.is_disposable ()) {
			return false;
		}

		if (type.type_parameter != null) {
			if (!(current_type_symbol is Class) || current_class.is_compact) {
				return false;
			}
		}

		return true;
	}

	private CCodeExpression? get_ref_cexpression (DataType expression_type, CCodeExpression cexpr, Expression? expr, CodeNode node) {
		if (expression_type is ValueType && !expression_type.nullable) {
			// normal value type, no null check
			// (copy (&expr, &temp), temp)

			var decl = get_temp_variable (expression_type, false, node);
			temp_vars.insert (0, decl);

			var ctemp = new CCodeIdentifier (decl.name);
			
			var vt = (ValueType) expression_type;
			var st = (Struct) vt.type_symbol;
			var copy_call = new CCodeFunctionCall (new CCodeIdentifier (st.get_copy_function ()));
			copy_call.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, cexpr));
			copy_call.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, ctemp));

			var ccomma = new CCodeCommaExpression ();
			ccomma.append_expression (copy_call);
			ccomma.append_expression (ctemp);

			return ccomma;
		}

		/* (temp = expr, temp == NULL ? NULL : ref (temp))
		 *
		 * can be simplified to
		 * ref (expr)
		 * if static type of expr is non-null
		 */
		 
		var dupexpr = get_dup_func_expression (expression_type, node.source_reference);

		if (dupexpr == null) {
			node.error = true;
			return null;
		}

		var ccall = new CCodeFunctionCall (dupexpr);

		if (expr != null && expr.is_non_null ()) {
			// expression is non-null
			ccall.add_argument ((CCodeExpression) expr.ccodenode);
			
			return ccall;
		} else {
			var decl = get_temp_variable (expression_type, false, node);
			temp_vars.insert (0, decl);

			var ctemp = new CCodeIdentifier (decl.name);
			
			var cisnull = new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, ctemp, new CCodeConstant ("NULL"));
			if (expression_type.type_parameter != null) {
				if (!(current_type_symbol is Class)) {
					return cexpr;
				}

				// dup functions are optional for type parameters
				var cdupisnull = new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, get_dup_func_expression (expression_type, node.source_reference), new CCodeConstant ("NULL"));
				cisnull = new CCodeBinaryExpression (CCodeBinaryOperator.OR, cisnull, cdupisnull);
			}

			if (expression_type.type_parameter != null) {
				// cast from gconstpointer to gpointer as GBoxedCopyFunc expects gpointer
				ccall.add_argument (new CCodeCastExpression (ctemp, "gpointer"));
			} else {
				ccall.add_argument (ctemp);
			}

			if (expression_type is ArrayType) {
				var array_type = (ArrayType) expression_type;
				bool first = true;
				CCodeExpression csizeexpr = null;
				for (int dim = 1; dim <= array_type.rank; dim++) {
					if (first) {
						csizeexpr = head.get_array_length_cexpression (expr, dim);
						first = false;
					} else {
						csizeexpr = new CCodeBinaryExpression (CCodeBinaryOperator.MUL, csizeexpr, head.get_array_length_cexpression (expr, dim));
					}
				}

				ccall.add_argument (csizeexpr);
			}

			var ccomma = new CCodeCommaExpression ();
			ccomma.append_expression (new CCodeAssignment (ctemp, cexpr));

			CCodeExpression cifnull;
			if (expression_type.data_type != null) {
				cifnull = new CCodeConstant ("NULL");
			} else {
				// the value might be non-null even when the dup function is null,
				// so we may not just use NULL for type parameters

				// cast from gconstpointer to gpointer as methods in
				// generic classes may not return gconstpointer
				cifnull = new CCodeCastExpression (ctemp, "gpointer");
			}
			ccomma.append_expression (new CCodeConditionalExpression (cisnull, cifnull, ccall));

			return ccomma;
		}
	}

	public override void visit_object_creation_expression (ObjectCreationExpression expr) {
		expr.accept_children (this);

		CCodeExpression instance = null;
		CCodeExpression creation_expr = null;

		var st = expr.type_reference.data_type as Struct;
		if ((st != null && !st.is_simple_type ()) || expr.get_object_initializer ().size > 0) {
			// value-type initialization or object creation expression with object initializer
			var temp_decl = get_temp_variable (expr.type_reference, false, expr);
			temp_vars.add (temp_decl);

			instance = new CCodeIdentifier (get_variable_cname (temp_decl.name));
		}

		if (expr.symbol_reference == null) {
			CCodeFunctionCall creation_call;

			// no creation method
			if (expr.type_reference.data_type == glist_type ||
			    expr.type_reference.data_type == gslist_type) {
				// NULL is an empty list
				expr.ccodenode = new CCodeConstant ("NULL");
			} else if (expr.type_reference.data_type is Class && expr.type_reference.data_type.is_subtype_of (gobject_type)) {
				creation_call = new CCodeFunctionCall (new CCodeIdentifier ("g_object_new"));
				creation_call.add_argument (new CCodeConstant (expr.type_reference.data_type.get_type_id ()));
				creation_call.add_argument (new CCodeConstant ("NULL"));
			} else if (expr.type_reference.data_type is Class) {
				creation_call = new CCodeFunctionCall (new CCodeIdentifier ("g_new0"));
				creation_call.add_argument (new CCodeConstant (expr.type_reference.data_type.get_cname ()));
				creation_call.add_argument (new CCodeConstant ("1"));
			} else if (expr.type_reference.data_type is Struct) {
				// memset needs string.h
				string_h_needed = true;
				creation_call = new CCodeFunctionCall (new CCodeIdentifier ("memset"));
				creation_call.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, instance));
				creation_call.add_argument (new CCodeConstant ("0"));
				creation_call.add_argument (new CCodeIdentifier ("sizeof (%s)".printf (expr.type_reference.get_cname ())));
			}

			creation_expr = creation_call;
		} else if (expr.symbol_reference is Method) {
			// use creation method
			var m = (Method) expr.symbol_reference;
			var params = m.get_parameters ();
			CCodeFunctionCall creation_call;

			creation_call = new CCodeFunctionCall (new CCodeIdentifier (m.get_cname ()));

			if ((st != null && !st.is_simple_type ()) && !(m.cinstance_parameter_position < 0)) {
				creation_call.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, instance));
			}

			var cl = expr.type_reference.data_type as Class;
			if (cl != null && !cl.is_compact) {
				foreach (DataType type_arg in expr.type_reference.get_type_arguments ()) {
					creation_call.add_argument (get_type_id_expression (type_arg));
					if (requires_copy (type_arg)) {
						var dup_func = get_dup_func_expression (type_arg, type_arg.source_reference);
						if (dup_func == null) {
							// type doesn't contain a copy function
							expr.error = true;
							return;
						}
						creation_call.add_argument (new CCodeCastExpression (dup_func, "GBoxedCopyFunc"));
						creation_call.add_argument (get_destroy_func_expression (type_arg));
					} else {
						creation_call.add_argument (new CCodeConstant ("NULL"));
						creation_call.add_argument (new CCodeConstant ("NULL"));
					}
				}
			}

			var carg_map = new HashMap<int,CCodeExpression> (direct_hash, direct_equal);

			bool ellipsis = false;

			int i = 1;
			int arg_pos;
			Iterator<FormalParameter> params_it = params.iterator ();
			foreach (Expression arg in expr.get_argument_list ()) {
				CCodeExpression cexpr = (CCodeExpression) arg.ccodenode;
				FormalParameter param = null;
				if (params_it.next ()) {
					param = params_it.get ();
					ellipsis = param.ellipsis;
					if (!ellipsis) {
						if (!param.no_array_length && param.parameter_type is ArrayType) {
							var array_type = (ArrayType) param.parameter_type;
							for (int dim = 1; dim <= array_type.rank; dim++) {
								carg_map.set (get_param_pos (param.carray_length_parameter_position + 0.01 * dim), head.get_array_length_cexpression (arg, dim));
							}
						} else if (param.parameter_type is DelegateType) {
							var deleg_type = (DelegateType) param.parameter_type;
							var d = deleg_type.delegate_symbol;
							if (d.has_target) {
								var delegate_target = get_delegate_target_cexpression (arg);
								carg_map.set (get_param_pos (param.cdelegate_target_parameter_position), delegate_target);
							}
						}

						cexpr = handle_struct_argument (param, arg, cexpr);
					}

					arg_pos = get_param_pos (param.cparameter_position, ellipsis);
				} else {
					// default argument position
					arg_pos = get_param_pos (i, ellipsis);
				}
			
				carg_map.set (arg_pos, cexpr);

				i++;
			}
			while (params_it.next ()) {
				var param = params_it.get ();
				
				if (param.ellipsis) {
					ellipsis = true;
					break;
				}
				
				if (param.default_expression == null) {
					Report.error (expr.source_reference, "no default expression for argument %d".printf (i));
					return;
				}
				
				/* evaluate default expression here as the code
				 * generator might not have visited the formal
				 * parameter yet */
				param.default_expression.accept (this);
			
				carg_map.set (get_param_pos (param.cparameter_position), (CCodeExpression) param.default_expression.ccodenode);
				i++;
			}

			// append C arguments in the right order
			int last_pos = -1;
			int min_pos;
			while (true) {
				min_pos = -1;
				foreach (int pos in carg_map.get_keys ()) {
					if (pos > last_pos && (min_pos == -1 || pos < min_pos)) {
						min_pos = pos;
					}
				}
				if (min_pos == -1) {
					break;
				}
				creation_call.add_argument (carg_map.get (min_pos));
				last_pos = min_pos;
			}

			if ((st != null && !st.is_simple_type ()) && m.cinstance_parameter_position < 0) {
				// instance parameter is at the end in a struct creation method
				creation_call.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, instance));
			}

			if (expr.tree_can_fail) {
				// method can fail
				current_method_inner_error = true;
				creation_call.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, new CCodeIdentifier ("inner_error")));
			}

			if (ellipsis) {
				/* ensure variable argument list ends with NULL
				 * except when using printf-style arguments */
				if (!m.printf_format && m.sentinel != "") {
					creation_call.add_argument (new CCodeConstant (m.sentinel));
				}
			}

			creation_expr = creation_call;

			// cast the return value of the creation method back to the intended type if
			// it requested a special C return type
			if (head.get_custom_creturn_type (m) != null) {
				creation_expr = new CCodeCastExpression (creation_expr, expr.type_reference.get_cname ());
			}
		} else if (expr.symbol_reference is ErrorCode) {
			var ecode = (ErrorCode) expr.symbol_reference;
			var edomain = (ErrorDomain) ecode.parent_symbol;
			CCodeFunctionCall creation_call;

			creation_call = new CCodeFunctionCall (new CCodeIdentifier ("g_error_new"));
			creation_call.add_argument (new CCodeIdentifier (edomain.get_upper_case_cname ()));
			creation_call.add_argument (new CCodeIdentifier (ecode.get_cname ()));

			foreach (Expression arg in expr.get_argument_list ()) {
				creation_call.add_argument ((CCodeExpression) arg.ccodenode);
			}

			creation_expr = creation_call;
		} else {
			assert (false);
		}
			
		if (instance != null) {
			var ccomma = new CCodeCommaExpression ();

			if (expr.type_reference.data_type is Struct) {
				ccomma.append_expression (creation_expr);
			} else {
				ccomma.append_expression (new CCodeAssignment (instance, creation_expr));
			}

			foreach (MemberInitializer init in expr.get_object_initializer ()) {
				if (init.symbol_reference is Field) {
					var f = (Field) init.symbol_reference;
					var instance_target_type = get_data_type_for_symbol ((TypeSymbol) f.parent_symbol);
					var typed_inst = transform_expression (instance, expr.type_reference, instance_target_type);
					CCodeExpression lhs;
					if (expr.type_reference.data_type is Struct) {
						lhs = new CCodeMemberAccess (typed_inst, f.get_cname ());
					} else {
						lhs = new CCodeMemberAccess.pointer (typed_inst, f.get_cname ());
					}
					ccomma.append_expression (new CCodeAssignment (lhs, (CCodeExpression) init.initializer.ccodenode));
				} else if (init.symbol_reference is Property) {
					var inst_ma = new MemberAccess.simple ("new");
					inst_ma.value_type = expr.type_reference;
					inst_ma.ccodenode = instance;
					var ma = new MemberAccess (inst_ma, init.name);
					ccomma.append_expression (get_property_set_call ((Property) init.symbol_reference, ma, (CCodeExpression) init.initializer.ccodenode));
				}
			}

			ccomma.append_expression (instance);

			expr.ccodenode = ccomma;
		} else if (creation_expr != null) {
			expr.ccodenode = creation_expr;
		}
	}

	public CCodeExpression? handle_struct_argument (FormalParameter param, Expression arg, CCodeExpression? cexpr) {
		// pass non-simple struct instances always by reference
		if (!(arg.value_type is NullType) && param.parameter_type.data_type is Struct && !((Struct) param.parameter_type.data_type).is_simple_type ()) {
			// we already use a reference for arguments of ref, out, and nullable parameters
			if (param.direction == ParameterDirection.IN && !param.parameter_type.nullable) {
				var unary = cexpr as CCodeUnaryExpression;
				if (unary != null && unary.operator == CCodeUnaryOperator.POINTER_INDIRECTION) {
					// *expr => expr
					return unary.inner;
				} else if (cexpr is CCodeIdentifier || cexpr is CCodeMemberAccess) {
					return new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, cexpr);
				} else {
					// if cexpr is e.g. a function call, we can't take the address of the expression
					// (tmp = expr, &tmp)
					var ccomma = new CCodeCommaExpression ();

					var temp_var = get_temp_variable (arg.value_type);
					temp_vars.insert (0, temp_var);
					ccomma.append_expression (new CCodeAssignment (new CCodeIdentifier (temp_var.name), cexpr));
					ccomma.append_expression (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, new CCodeIdentifier (temp_var.name)));

					return ccomma;
				}
			}
		}

		return cexpr;
	}

	public override void visit_sizeof_expression (SizeofExpression expr) {
		var csizeof = new CCodeFunctionCall (new CCodeIdentifier ("sizeof"));
		csizeof.add_argument (new CCodeIdentifier (expr.type_reference.get_cname ()));
		expr.ccodenode = csizeof;
	}

	public override void visit_typeof_expression (TypeofExpression expr) {
		expr.ccodenode = get_type_id_expression (expr.type_reference);
	}

	public override void visit_unary_expression (UnaryExpression expr) {
		expr.accept_children (this);

		CCodeUnaryOperator op;
		if (expr.operator == UnaryOperator.PLUS) {
			op = CCodeUnaryOperator.PLUS;
		} else if (expr.operator == UnaryOperator.MINUS) {
			op = CCodeUnaryOperator.MINUS;
		} else if (expr.operator == UnaryOperator.LOGICAL_NEGATION) {
			op = CCodeUnaryOperator.LOGICAL_NEGATION;
		} else if (expr.operator == UnaryOperator.BITWISE_COMPLEMENT) {
			op = CCodeUnaryOperator.BITWISE_COMPLEMENT;
		} else if (expr.operator == UnaryOperator.INCREMENT) {
			op = CCodeUnaryOperator.PREFIX_INCREMENT;
		} else if (expr.operator == UnaryOperator.DECREMENT) {
			op = CCodeUnaryOperator.PREFIX_DECREMENT;
		} else if (expr.operator == UnaryOperator.REF) {
			op = CCodeUnaryOperator.ADDRESS_OF;
		} else if (expr.operator == UnaryOperator.OUT) {
			op = CCodeUnaryOperator.ADDRESS_OF;
		}
		expr.ccodenode = new CCodeUnaryExpression (op, (CCodeExpression) expr.inner.ccodenode);
	}

	public override void visit_cast_expression (CastExpression expr) {
		var cl = expr.type_reference.data_type as Class;
		var iface = expr.type_reference.data_type as Interface;
		if (iface != null || (cl != null && !cl.is_compact)) {
			// checked cast for strict subtypes of GTypeInstance
			if (expr.is_silent_cast) {
				var ccomma = new CCodeCommaExpression ();
				var temp_decl = get_temp_variable (expr.inner.value_type, true, expr);

				temp_vars.add (temp_decl);

				var ctemp = new CCodeIdentifier (temp_decl.name);
				var cinit = new CCodeAssignment (ctemp, (CCodeExpression) expr.inner.ccodenode);
				var ccheck = create_type_check (ctemp, expr.type_reference);
				var ccast = new CCodeCastExpression (ctemp, expr.type_reference.get_cname ());
				var cnull = new CCodeConstant ("NULL");

				ccomma.append_expression (cinit);
				ccomma.append_expression (new CCodeConditionalExpression (ccheck, ccast, cnull));
	
				expr.ccodenode = ccomma;
			} else {
				expr.ccodenode = new InstanceCast ((CCodeExpression) expr.inner.ccodenode, expr.type_reference.data_type);
			}
		} else {
			if (expr.is_silent_cast) {
				expr.error = true;
				Report.error (expr.source_reference, "Operation not supported for this type");
				return;
			}
			expr.ccodenode = new CCodeCastExpression ((CCodeExpression) expr.inner.ccodenode, expr.type_reference.get_cname ());
		}
	}
	
	public override void visit_pointer_indirection (PointerIndirection expr) {
		expr.ccodenode = new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, (CCodeExpression) expr.inner.ccodenode);
	}

	public override void visit_addressof_expression (AddressofExpression expr) {
		expr.ccodenode = new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, (CCodeExpression) expr.inner.ccodenode);
	}

	public override void visit_reference_transfer_expression (ReferenceTransferExpression expr) {
		expr.accept_children (this);

		/* (tmp = var, var = null, tmp) */
		var ccomma = new CCodeCommaExpression ();
		var temp_decl = get_temp_variable (expr.value_type, true, expr);
		temp_vars.insert (0, temp_decl);
		var cvar = new CCodeIdentifier (temp_decl.name);

		ccomma.append_expression (new CCodeAssignment (cvar, (CCodeExpression) expr.inner.ccodenode));
		ccomma.append_expression (new CCodeAssignment ((CCodeExpression) expr.inner.ccodenode, new CCodeConstant ("NULL")));
		ccomma.append_expression (cvar);
		expr.ccodenode = ccomma;
	}

	public override void visit_binary_expression (BinaryExpression expr) {
		var cleft = (CCodeExpression) expr.left.ccodenode;
		var cright = (CCodeExpression) expr.right.ccodenode;
		
		CCodeBinaryOperator op;
		if (expr.operator == BinaryOperator.PLUS) {
			op = CCodeBinaryOperator.PLUS;
		} else if (expr.operator == BinaryOperator.MINUS) {
			op = CCodeBinaryOperator.MINUS;
		} else if (expr.operator == BinaryOperator.MUL) {
			op = CCodeBinaryOperator.MUL;
		} else if (expr.operator == BinaryOperator.DIV) {
			op = CCodeBinaryOperator.DIV;
		} else if (expr.operator == BinaryOperator.MOD) {
			op = CCodeBinaryOperator.MOD;
		} else if (expr.operator == BinaryOperator.SHIFT_LEFT) {
			op = CCodeBinaryOperator.SHIFT_LEFT;
		} else if (expr.operator == BinaryOperator.SHIFT_RIGHT) {
			op = CCodeBinaryOperator.SHIFT_RIGHT;
		} else if (expr.operator == BinaryOperator.LESS_THAN) {
			op = CCodeBinaryOperator.LESS_THAN;
		} else if (expr.operator == BinaryOperator.GREATER_THAN) {
			op = CCodeBinaryOperator.GREATER_THAN;
		} else if (expr.operator == BinaryOperator.LESS_THAN_OR_EQUAL) {
			op = CCodeBinaryOperator.LESS_THAN_OR_EQUAL;
		} else if (expr.operator == BinaryOperator.GREATER_THAN_OR_EQUAL) {
			op = CCodeBinaryOperator.GREATER_THAN_OR_EQUAL;
		} else if (expr.operator == BinaryOperator.EQUALITY) {
			op = CCodeBinaryOperator.EQUALITY;
		} else if (expr.operator == BinaryOperator.INEQUALITY) {
			op = CCodeBinaryOperator.INEQUALITY;
		} else if (expr.operator == BinaryOperator.BITWISE_AND) {
			op = CCodeBinaryOperator.BITWISE_AND;
		} else if (expr.operator == BinaryOperator.BITWISE_OR) {
			op = CCodeBinaryOperator.BITWISE_OR;
		} else if (expr.operator == BinaryOperator.BITWISE_XOR) {
			op = CCodeBinaryOperator.BITWISE_XOR;
		} else if (expr.operator == BinaryOperator.AND) {
			op = CCodeBinaryOperator.AND;
		} else if (expr.operator == BinaryOperator.OR) {
			op = CCodeBinaryOperator.OR;
		} else if (expr.operator == BinaryOperator.IN) {
			var container_type = expr.right.value_type.data_type;
			if (container_type != null && collection_type != null && map_type != null &&
		           (container_type.is_subtype_of (collection_type) || container_type.is_subtype_of (map_type))) {
				Method contains_method;
				if (container_type.is_subtype_of (collection_type)) {
					contains_method = (Method) collection_type.scope.lookup ("contains");
					assert (contains_method != null);
					var contains_ccall = new CCodeFunctionCall (new CCodeIdentifier (contains_method.get_cname ()));
					contains_ccall.add_argument (new InstanceCast (cright, collection_type));
					contains_ccall.add_argument (cleft);
					expr.ccodenode = contains_ccall;
				} else {
					contains_method = (Method) map_type.scope.lookup ("contains");
					assert (contains_method != null);
					var contains_ccall = new CCodeFunctionCall (new CCodeIdentifier (contains_method.get_cname ()));
					contains_ccall.add_argument (new InstanceCast (cright, map_type));
					contains_ccall.add_argument (cleft);
					expr.ccodenode = contains_ccall;
				}
				return;
			}
		
			expr.ccodenode = new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, new CCodeParenthesizedExpression (new CCodeBinaryExpression (CCodeBinaryOperator.BITWISE_AND, new CCodeParenthesizedExpression (cright), new CCodeParenthesizedExpression (cleft))), new CCodeParenthesizedExpression (cleft));
			return;
		}
		
		if (expr.operator == BinaryOperator.EQUALITY ||
		    expr.operator == BinaryOperator.INEQUALITY) {
			var left_type_as_struct = expr.left.value_type.data_type as Struct;
			var right_type_as_struct = expr.right.value_type.data_type as Struct;

			if (expr.left.value_type.data_type is Class && !((Class) expr.left.value_type.data_type).is_compact &&
			    expr.right.value_type.data_type is Class && !((Class) expr.right.value_type.data_type).is_compact) {
				var left_cl = (Class) expr.left.value_type.data_type;
				var right_cl = (Class) expr.right.value_type.data_type;
				
				if (left_cl != right_cl) {
					if (left_cl.is_subtype_of (right_cl)) {
						cleft = new InstanceCast (cleft, right_cl);
					} else if (right_cl.is_subtype_of (left_cl)) {
						cright = new InstanceCast (cright, left_cl);
					}
				}
			} else if (left_type_as_struct != null && expr.right.value_type is NullType) {
				cleft = new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, cleft);
			} else if (right_type_as_struct != null && expr.left.value_type is NullType) {
				cright = new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, cright);
			}
		}

		if (!(expr.left.value_type is NullType)
		    && expr.left.value_type.compatible (string_type)
		    && !(expr.right.value_type is NullType)
		    && expr.right.value_type.compatible (string_type)) {
			if (expr.operator == BinaryOperator.PLUS) {
				// string concatenation
				if (expr.left.is_constant () && expr.right.is_constant ()) {
					string left, right;

					if (cleft is CCodeIdentifier) {
						left = ((CCodeIdentifier) cleft).name;
					} else if (cleft is CCodeConstant) {
						left = ((CCodeConstant) cleft).name;
					}
					if (cright is CCodeIdentifier) {
						right = ((CCodeIdentifier) cright).name;
					} else if (cright is CCodeConstant) {
						right = ((CCodeConstant) cright).name;
					}

					expr.ccodenode = new CCodeConstant ("%s %s".printf (left, right));
					return;
				} else {
					// convert to g_strconcat (a, b, NULL)
					var ccall = new CCodeFunctionCall (new CCodeIdentifier ("g_strconcat"));
					ccall.add_argument (cleft);
					ccall.add_argument (cright);
					ccall.add_argument (new CCodeConstant("NULL"));
					expr.ccodenode = ccall;
					return;
				}
			} else if (expr.operator == BinaryOperator.EQUALITY
			           || expr.operator == BinaryOperator.INEQUALITY
			           || expr.operator == BinaryOperator.LESS_THAN
			           || expr.operator == BinaryOperator.GREATER_THAN
			           || expr.operator == BinaryOperator.LESS_THAN_OR_EQUAL
			           || expr.operator == BinaryOperator.GREATER_THAN_OR_EQUAL) {
				requires_strcmp0 = true;
				var ccall = new CCodeFunctionCall (new CCodeIdentifier ("_vala_strcmp0"));
				ccall.add_argument (cleft);
				ccall.add_argument (cright);
				cleft = ccall;
				cright = new CCodeConstant ("0");
			}
		}

		expr.ccodenode = new CCodeBinaryExpression (op, cleft, cright);
	}

	public string get_type_check_function (TypeSymbol type) {
		var cl = type as Class;
		if (cl != null && cl.type_check_function != null) {
			return cl.type_check_function;
		} else {
			return type.get_upper_case_cname ("IS_");
		}
	}

	CCodeExpression create_type_check (CCodeNode ccodenode, DataType type) {
		var et = type as ErrorType;
		if (et != null && et.error_code != null) {
			var matches_call = new CCodeFunctionCall (new CCodeIdentifier ("g_error_matches"));
			matches_call.add_argument ((CCodeExpression) ccodenode);
			matches_call.add_argument (new CCodeIdentifier (et.error_domain.get_upper_case_cname ()));
			matches_call.add_argument (new CCodeIdentifier (et.error_code.get_cname ()));
			return matches_call;
		} else if (et != null && et.error_domain != null) {
			var instance_domain = new CCodeMemberAccess.pointer ((CCodeExpression) ccodenode, "domain");
			var type_domain = new CCodeIdentifier (et.error_domain.get_upper_case_cname ());
			return new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, instance_domain, type_domain);
		} else {
			var ccheck = new CCodeFunctionCall (new CCodeIdentifier (get_type_check_function (type.data_type)));
			ccheck.add_argument ((CCodeExpression) ccodenode);
			return ccheck;
		}
	}

	public override void visit_type_check (TypeCheck expr) {
		expr.ccodenode = create_type_check (expr.expression.ccodenode, expr.type_reference);
	}

	public override void visit_conditional_expression (ConditionalExpression expr) {
		expr.ccodenode = new CCodeConditionalExpression ((CCodeExpression) expr.condition.ccodenode, (CCodeExpression) expr.true_expression.ccodenode, (CCodeExpression) expr.false_expression.ccodenode);
	}

	public override void visit_lambda_expression (LambdaExpression l) {
		// use instance position from delegate
		var dt = (DelegateType) l.target_type;
		l.method.cinstance_parameter_position = dt.delegate_symbol.cinstance_parameter_position;

		var old_temp_vars = temp_vars;
		var old_temp_ref_vars = temp_ref_vars;
		temp_vars = new ArrayList<LocalVariable> ();
		temp_ref_vars = new ArrayList<LocalVariable> ();

		l.accept_children (this);

		temp_vars = old_temp_vars;
		temp_ref_vars = old_temp_ref_vars;

		l.ccodenode = new CCodeIdentifier (l.method.get_cname ());
	}

	public CCodeExpression convert_from_generic_pointer (CCodeExpression cexpr, DataType actual_type) {
		var result = cexpr;
		if (actual_type.data_type is Struct) {
			var st = (Struct) actual_type.data_type;
			if (st == uint_type.data_type) {
				var cconv = new CCodeFunctionCall (new CCodeIdentifier ("GPOINTER_TO_UINT"));
				cconv.add_argument (cexpr);
				result = cconv;
			} else if (st == bool_type.data_type || st.is_integer_type ()) {
				var cconv = new CCodeFunctionCall (new CCodeIdentifier ("GPOINTER_TO_INT"));
				cconv.add_argument (cexpr);
				result = cconv;
			}
		} else if (actual_type.data_type != null && actual_type.data_type.is_reference_type ()) {
			result = new CCodeCastExpression (cexpr, actual_type.get_cname ());
		}
		return result;
	}

	public CCodeExpression convert_to_generic_pointer (CCodeExpression cexpr, DataType actual_type) {
		var result = cexpr;
		if (actual_type.data_type is Struct) {
			var st = (Struct) actual_type.data_type;
			if (st == uint_type.data_type) {
				var cconv = new CCodeFunctionCall (new CCodeIdentifier ("GUINT_TO_POINTER"));
				cconv.add_argument (cexpr);
				result = cconv;
			} else if (st == bool_type.data_type || st.is_integer_type ()) {
				var cconv = new CCodeFunctionCall (new CCodeIdentifier ("GINT_TO_POINTER"));
				cconv.add_argument (cexpr);
				result = cconv;
			}
		}
		return result;
	}

	// manage memory and implicit casts
	public CCodeExpression transform_expression (CCodeExpression source_cexpr, DataType? expression_type, DataType? target_type, Expression? expr = null) {
		var cexpr = source_cexpr;
		if (expression_type == null) {
			return cexpr;
		}


		if (expression_type.value_owned
		    && expression_type.floating_reference) {
			/* constructor of GInitiallyUnowned subtype
			 * returns floating reference, sink it
			 */
			var csink = new CCodeFunctionCall (new CCodeIdentifier ("g_object_ref_sink"));
			csink.add_argument (cexpr);
			
			cexpr = csink;
		}

		bool boxing = (expression_type is ValueType && !expression_type.nullable
		               && target_type is ValueType && target_type.nullable);
		bool unboxing = (expression_type is ValueType && expression_type.nullable
		                 && target_type is ValueType && !target_type.nullable);

		if (expression_type.value_owned
		    && (target_type == null || !target_type.value_owned || boxing || unboxing)) {
			// value leaked, destroy it
			var pointer_type = target_type as PointerType;
			if (pointer_type != null && !(pointer_type.base_type is VoidType)) {
				// manual memory management for non-void pointers
				// treat void* special to not leak memory with void* method parameters
			} else if (requires_destroy (expression_type)) {
				var decl = get_temp_variable (expression_type, true, expression_type);
				temp_vars.insert (0, decl);
				temp_ref_vars.insert (0, decl);
				cexpr = new CCodeParenthesizedExpression (new CCodeAssignment (new CCodeIdentifier (get_variable_cname (decl.name)), cexpr));

				if (expression_type is ArrayType && expr != null) {
					var array_type = (ArrayType) expression_type;
					var ccomma = new CCodeCommaExpression ();
					ccomma.append_expression (cexpr);
					for (int dim = 1; dim <= array_type.rank; dim++) {
						var len_decl = new LocalVariable (int_type.copy (), head.get_array_length_cname (decl.name, dim));
						temp_vars.insert (0, len_decl);
						ccomma.append_expression (new CCodeAssignment (new CCodeIdentifier (get_variable_cname (len_decl.name)), head.get_array_length_cexpression (expr, dim)));
					}
					ccomma.append_expression (new CCodeIdentifier (get_variable_cname (decl.name)));
					cexpr = ccomma;
				}
			}
		}

		if (target_type == null) {
			// value will be destroyed, no need for implicit casts
			return cexpr;
		}

		if (boxing) {
			// value needs to be boxed

			var unary = cexpr as CCodeUnaryExpression;
			if (unary != null && unary.operator == CCodeUnaryOperator.POINTER_INDIRECTION) {
				// *expr => expr
				cexpr = unary.inner;
			} else if (cexpr is CCodeIdentifier || cexpr is CCodeMemberAccess) {
				cexpr = new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, cexpr);
			} else {
				var decl = get_temp_variable (expression_type, expression_type.value_owned, expression_type);
				temp_vars.insert (0, decl);

				var ccomma = new CCodeCommaExpression ();
				ccomma.append_expression (new CCodeAssignment (new CCodeIdentifier (get_variable_cname (decl.name)), cexpr));
				ccomma.append_expression (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, new CCodeIdentifier (get_variable_cname (decl.name))));
				cexpr = ccomma;
			}
		} else if (unboxing) {
			// unbox value

			cexpr = new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, cexpr);
		} else {
			cexpr = get_implicit_cast_expression (cexpr, expression_type, target_type, expr);
		}

		if (expression_type.is_type_argument) {
			cexpr = convert_from_generic_pointer (cexpr, target_type);
		} else if (target_type.is_type_argument) {
			cexpr = convert_to_generic_pointer (cexpr, expression_type);
		}

		if (target_type.value_owned && (!expression_type.value_owned || boxing || unboxing)) {
			// need to copy value
			if (requires_copy (target_type) && !(expression_type is NullType)) {
				CodeNode node = expr;
				if (node == null) {
					node = expression_type;
				}
				cexpr = get_ref_cexpression (target_type, cexpr, expr, node);
			}
		}

		return cexpr;
	}

	private CCodeExpression get_implicit_cast_expression (CCodeExpression source_cexpr, DataType? expression_type, DataType? target_type, Expression? expr = null) {
		var cexpr = source_cexpr;

		if (expression_type.data_type != null && expression_type.data_type == target_type.data_type) {
			// same type, no cast required
			return cexpr;
		}

		if (expression_type is NullType) {
			// null literal, no cast required when not converting to generic type pointer
			return cexpr;
		}

		var cl = target_type.data_type as Class;
		var iface = target_type.data_type as Interface;
		if (context.checking && (iface != null || (cl != null && !cl.is_compact))) {
			// checked cast for strict subtypes of GTypeInstance
			return new InstanceCast (cexpr, target_type.data_type);
		} else if (target_type.data_type != null && expression_type.get_cname () != target_type.get_cname ()) {
			var st = target_type.data_type as Struct;
			if (target_type.data_type.is_reference_type () || (st != null && st.is_simple_type ())) {
				// don't cast non-simple structs
				return new CCodeCastExpression (cexpr, target_type.get_cname ());
			} else {
				return cexpr;
			}
		} else if (target_type is DelegateType && expression_type is MethodType) {
			var dt = (DelegateType) target_type;
			var mt = (MethodType) expression_type;

			var method = mt.method_symbol;
			if (method.base_method != null) {
				method = method.base_method;
			} else if (method.base_interface_method != null) {
				method = method.base_interface_method;
			}

			return new CCodeIdentifier (generate_delegate_wrapper (method, dt.delegate_symbol));
		} else {
			return cexpr;
		}
	}

	private string generate_delegate_wrapper (Method m, Delegate d) {
		string delegate_name;
		var sig = d.parent_symbol as Signal;
		var dynamic_sig = sig as DynamicSignal;
		if (dynamic_sig != null) {
			delegate_name = head.get_dynamic_signal_cname (dynamic_sig);
		} else if (sig != null) {
			delegate_name = sig.parent_symbol.get_lower_case_cprefix () + sig.get_cname ();
		} else {
			delegate_name = Symbol.camel_case_to_lower_case (d.get_cname ());
		}

		string wrapper_name = "_%s_%s".printf (m.get_cname (), delegate_name);

		if (!add_wrapper (wrapper_name)) {
			// wrapper already defined
			return wrapper_name;
		}

		// declaration

		var function = new CCodeFunction (wrapper_name, m.return_type.get_cname ());
		function.modifiers = CCodeModifiers.STATIC;
		m.ccodenode = function;

		var cparam_map = new HashMap<int,CCodeFormalParameter> (direct_hash, direct_equal);

		if (d.has_target) {
			var cparam = new CCodeFormalParameter ("self", "gpointer");
			cparam_map.set (get_param_pos (d.cinstance_parameter_position), cparam);
		}

		var d_params = d.get_parameters ();
		foreach (FormalParameter param in d_params) {
			// ensure that C code node has been generated
			param.accept (this);

			cparam_map.set (get_param_pos (param.cparameter_position), (CCodeFormalParameter) param.ccodenode);

			// handle array parameters
			if (!param.no_array_length && param.parameter_type is ArrayType) {
				var array_type = (ArrayType) param.parameter_type;
				
				var length_ctype = "int";
				if (param.direction != ParameterDirection.IN) {
					length_ctype = "int*";
				}
				
				for (int dim = 1; dim <= array_type.rank; dim++) {
					var cparam = new CCodeFormalParameter (head.get_array_length_cname (param.name, dim), length_ctype);
					cparam_map.set (get_param_pos (param.carray_length_parameter_position + 0.01 * dim), cparam);
				}
			}

		}

		if (m.get_error_types ().size > 0) {
			var cparam = new CCodeFormalParameter ("error", "GError**");
			cparam_map.set (get_param_pos (-1), cparam);
		}

		// append C parameters in the right order
		int last_pos = -1;
		int min_pos;
		while (true) {
			min_pos = -1;
			foreach (int pos in cparam_map.get_keys ()) {
				if (pos > last_pos && (min_pos == -1 || pos < min_pos)) {
					min_pos = pos;
				}
			}
			if (min_pos == -1) {
				break;
			}
			function.add_parameter (cparam_map.get (min_pos));
			last_pos = min_pos;
		}


		// definition

		var carg_map = new HashMap<int,CCodeExpression> (direct_hash, direct_equal);

		int i = 0;
		if (m.binding == MemberBinding.INSTANCE) {
			CCodeExpression arg;
			if (d.has_target) {
				arg = new CCodeIdentifier ("self");
			} else {
				// use first delegate parameter as instance
				arg = new CCodeIdentifier ((d_params.get (0).ccodenode as CCodeFormalParameter).name);
				i = 1;
			}
			carg_map.set (get_param_pos (m.cinstance_parameter_position), arg);
		}

		foreach (FormalParameter param in m.get_parameters ()) {
			CCodeExpression arg;
			arg = new CCodeIdentifier ((d_params.get (i).ccodenode as CCodeFormalParameter).name);
			carg_map.set (get_param_pos (param.cparameter_position), arg);

			// handle array arguments
			if (!param.no_array_length && param.parameter_type is ArrayType) {
				var array_type = (ArrayType) param.parameter_type;
				for (int dim = 1; dim <= array_type.rank; dim++) {
					CCodeExpression clength;
					if (d_params.get (i).no_array_length) {
						clength = new CCodeConstant ("-1");
					} else {
						clength = new CCodeIdentifier (head.get_array_length_cname (d_params.get (i).name, dim));
					}
					carg_map.set (get_param_pos (param.carray_length_parameter_position + 0.01 * dim), clength);
				}
			}

			i++;
		}

		if (m.get_error_types ().size > 0) {
			carg_map.set (get_param_pos (-1), new CCodeIdentifier ("error"));
		}

		var ccall = new CCodeFunctionCall (new CCodeIdentifier (m.get_cname ()));

		// append C arguments in the right order
		last_pos = -1;
		while (true) {
			min_pos = -1;
			foreach (int pos in carg_map.get_keys ()) {
				if (pos > last_pos && (min_pos == -1 || pos < min_pos)) {
					min_pos = pos;
				}
			}
			if (min_pos == -1) {
				break;
			}
			ccall.add_argument (carg_map.get (min_pos));
			last_pos = min_pos;
		}

		var block = new CCodeBlock ();
		if (m.return_type is VoidType) {
			block.add_statement (new CCodeExpressionStatement (ccall));
		} else {
			block.add_statement (new CCodeReturnStatement (ccall));
		}

		// append to file

		source_type_member_declaration.append (function.copy ());

		function.block = block;
		source_type_member_definition.append (function);

		return wrapper_name;
	}

	public override void visit_assignment (Assignment a) {
		head.visit_assignment (a);
	}

	public CCodeFunctionCall get_property_set_call (Property prop, MemberAccess ma, CCodeExpression cexpr) {
		if (ma.inner is BaseAccess) {
			if (prop.base_property != null) {
				var base_class = (Class) prop.base_property.parent_symbol;
				var vcast = new CCodeFunctionCall (new CCodeIdentifier ("%s_CLASS".printf (base_class.get_upper_case_cname (null))));
				vcast.add_argument (new CCodeIdentifier ("%s_parent_class".printf (current_class.get_lower_case_cname (null))));
				
				var ccall = new CCodeFunctionCall (new CCodeMemberAccess.pointer (vcast, "set_%s".printf (prop.name)));
				ccall.add_argument ((CCodeExpression) get_ccodenode (ma.inner));
				ccall.add_argument (cexpr);
				return ccall;
			} else if (prop.base_interface_property != null) {
				var base_iface = (Interface) prop.base_interface_property.parent_symbol;
				string parent_iface_var = "%s_%s_parent_iface".printf (current_class.get_lower_case_cname (null), base_iface.get_lower_case_cname (null));

				var ccall = new CCodeFunctionCall (new CCodeMemberAccess.pointer (new CCodeIdentifier (parent_iface_var), "set_%s".printf (prop.name)));
				ccall.add_argument ((CCodeExpression) get_ccodenode (ma.inner));
				ccall.add_argument (cexpr);
				return ccall;
			}
		}

		var set_func = "g_object_set";
		
		var base_property = prop;
		if (!prop.no_accessor_method) {
			if (prop.base_property != null) {
				base_property = prop.base_property;
			} else if (prop.base_interface_property != null) {
				base_property = prop.base_interface_property;
			}
			var base_property_type = (TypeSymbol) base_property.parent_symbol;
			set_func = "%s_set_%s".printf (base_property_type.get_lower_case_cname (null), base_property.name);
			if (prop is DynamicProperty) {
				set_func = head.get_dynamic_property_setter_cname ((DynamicProperty) prop);
			}
		}
		
		var ccall = new CCodeFunctionCall (new CCodeIdentifier (set_func));

		if (prop.binding == MemberBinding.INSTANCE) {
			/* target instance is first argument */
			ccall.add_argument ((CCodeExpression) get_ccodenode (ma.inner));
		}

		if (prop.no_accessor_method) {
			/* property name is second argument of g_object_set */
			ccall.add_argument (prop.get_canonical_cconstant ());
		}
			
		ccall.add_argument (cexpr);
		
		if (prop.no_accessor_method) {
			ccall.add_argument (new CCodeConstant ("NULL"));
		}

		return ccall;
	}

	/* indicates whether a given Expression eligable for an ADDRESS_OF operator
	 * from a vala to C point of view all expressions denoting locals, fields and
	 * parameters are eligable to an ADDRESS_OF operator */
	public bool is_address_of_possible (Expression e) {
		var ma = e as MemberAccess;

		if (ma == null) {
			return false;
		}
		if (ma.symbol_reference == null) {
			return false;
		}
		if (ma.symbol_reference is FormalParameter) {
			return true;
		}
		if (ma.symbol_reference is LocalVariable) {
			return true;
		}
		if (ma.symbol_reference is Field) {
			return true;
		}
		return false;
	}

	/* retrieve the correct address_of expression for a give expression, creates temporary variables
	 * where necessary, ce is the corresponding ccode expression for e */
	public CCodeExpression get_address_of_expression (Expression e, CCodeExpression ce) {
		// is address of trivially possible?
		if (is_address_of_possible (e)) {
			return new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, ce);
		}

		var ccomma = new CCodeCommaExpression ();
		var temp_decl = get_temp_variable (e.value_type);
		var ctemp = new CCodeIdentifier (temp_decl.name);
		temp_vars.add (temp_decl);
		ccomma.append_expression (new CCodeAssignment (ctemp, ce));
		ccomma.append_expression (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, ctemp));
		return ccomma;
	}

	public bool add_wrapper (string wrapper_name) {
		return wrappers.add (wrapper_name);
	}

	public static DataType get_data_type_for_symbol (TypeSymbol sym) {
		DataType type = null;

		if (sym is Class) {
			type = new ObjectType ((Class) sym);
		} else if (sym is Interface) {
			type = new ObjectType ((Interface) sym);
		} else if (sym is Struct) {
			type = new ValueType ((Struct) sym);
		} else if (sym is Enum) {
			type = new ValueType ((Enum) sym);
		} else if (sym is ErrorDomain) {
			type = new ErrorType ((ErrorDomain) sym, null);
		} else if (sym is ErrorCode) {
			type = new ErrorType ((ErrorDomain) sym.parent_symbol, (ErrorCode) sym);
		} else {
			Report.error (null, "internal error: `%s' is not a supported type".printf (sym.get_full_name ()));
			return new InvalidType ();
		}

		return type;
	}

	public CCodeExpression? default_value_for_type (DataType type, bool initializer_expression) {
		if ((type.data_type != null && type.data_type.is_reference_type ()) || type is PointerType || type is ArrayType) {
			return new CCodeConstant ("NULL");
		} else if (type.data_type != null && type.data_type.get_default_value () != null) {
			return new CCodeConstant (type.data_type.get_default_value ());
		} else if (type.data_type is Struct && initializer_expression) {
			// 0-initialize struct with struct initializer { 0 }
			// only allowed as initializer expression in C
			var clist = new CCodeInitializerList ();
			clist.append (new CCodeConstant ("0"));
			return clist;
		} else if (type.type_parameter != null) {
			return new CCodeConstant ("NULL");
		} else if (type is ErrorType) {
			return new CCodeConstant ("NULL");
		}
		return null;
	}
	
	private CCodeStatement create_property_type_check_statement (Property prop, bool check_return_type, TypeSymbol t, bool non_null, string var_name) {
		if (check_return_type) {
			return create_type_check_statement (prop, prop.property_type, t, non_null, var_name);
		} else {
			return create_type_check_statement (prop, new VoidType (), t, non_null, var_name);
		}
	}

	public CCodeStatement? create_type_check_statement (CodeNode method_node, DataType ret_type, TypeSymbol t, bool non_null, string var_name) {
		var ccheck = new CCodeFunctionCall ();
		
		if (context.checking && ((t is Class && !((Class) t).is_compact) || t is Interface)) {
			var ctype_check = new CCodeFunctionCall (new CCodeIdentifier (get_type_check_function (t)));
			ctype_check.add_argument (new CCodeIdentifier (var_name));
			
			CCodeExpression cexpr = ctype_check;
			if (!non_null) {
				var cnull = new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, new CCodeIdentifier (var_name), new CCodeConstant ("NULL"));
			
				cexpr = new CCodeBinaryExpression (CCodeBinaryOperator.OR, cnull, ctype_check);
			}
			ccheck.add_argument (cexpr);
		} else if (!non_null) {
			return null;
		} else {
			var cnonnull = new CCodeBinaryExpression (CCodeBinaryOperator.INEQUALITY, new CCodeIdentifier (var_name), new CCodeConstant ("NULL"));
			ccheck.add_argument (cnonnull);
		}
		
		if (ret_type is VoidType) {
			/* void function */
			ccheck.call = new CCodeIdentifier ("g_return_if_fail");
		} else {
			ccheck.call = new CCodeIdentifier ("g_return_val_if_fail");

			var cdefault = default_value_for_type (ret_type, false);
			if (cdefault != null) {
				ccheck.add_argument (cdefault);
			} else {
				return new CCodeExpressionStatement (new CCodeConstant ("0"));
			}
		}
		
		return new CCodeExpressionStatement (ccheck);
	}

	public int get_param_pos (double param_pos, bool ellipsis = false) {
		if (!ellipsis) {
			if (param_pos >= 0) {
				return (int) (param_pos * 1000);
			} else {
				return (int) ((100 + param_pos) * 1000);
			}
		} else {
			if (param_pos >= 0) {
				return (int) ((100 + param_pos) * 1000);
			} else {
				return (int) ((200 + param_pos) * 1000);
			}
		}
	}

	public bool dbus_use_ptr_array (ArrayType array_type) {
		if (array_type.element_type.data_type == string_type.data_type) {
			// use char**
			return false;
		} else if (array_type.element_type.data_type == bool_type.data_type
		           || array_type.element_type.data_type == char_type.data_type
		           || array_type.element_type.data_type == uchar_type.data_type
		           || array_type.element_type.data_type == int_type.data_type
		           || array_type.element_type.data_type == uint_type.data_type
		           || array_type.element_type.data_type == long_type.data_type
		           || array_type.element_type.data_type == ulong_type.data_type
		           || array_type.element_type.data_type == int8_type.data_type
		           || array_type.element_type.data_type == uint8_type.data_type
		           || array_type.element_type.data_type == int32_type.data_type
		           || array_type.element_type.data_type == uint32_type.data_type
		           || array_type.element_type.data_type == int64_type.data_type
		           || array_type.element_type.data_type == uint64_type.data_type
		           || array_type.element_type.data_type == double_type.data_type) {
			// use GArray
			return false;
		} else {
			// use GPtrArray
			return true;
		}
	}

	public CCodeNode? get_ccodenode (CodeNode node) {
		if (node.ccodenode == null) {
			node.accept (this);
		}
		return node.ccodenode;
	}
}
