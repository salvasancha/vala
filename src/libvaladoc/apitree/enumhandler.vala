/*
 * Valadoc - a documentation tool for vala.
 * Copyright (C) 2008 Florian Brosch
 * 
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

using Vala;
using GLib;
using Gee;

public interface Valadoc.EnumHandler : Api.Node {
	public Gee.Collection<Enum> get_enum_list () {
		return get_children_by_type (Api.NodeType.ENUM);
	}

	public void visit_enums ( Doclet doclet ) {
		accept_children_by_type (Api.NodeType.ENUM, doclet);
	}

	public void add_enums ( Gee.Collection<Vala.Enum> venums ) {
		foreach ( Vala.Enum venum in venums ) {
			this.add_enum ( venum );
		}
	}

	public void add_enum ( Vala.Enum venum ) {
		Enum tmp = new Enum (this.settings, venum, this);
		add_child (tmp);
	}
}
