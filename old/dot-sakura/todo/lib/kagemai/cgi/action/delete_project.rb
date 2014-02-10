=begin
  DeleteProject - プロジェクトを削除します

  Copyright(C) 2002, 2003 FUKUOKA Tomoyuki.

  This file is part of KAGEMAI.  

  KAGEMAI is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

  $Id: delete_project.rb,v 1.1.1.1 2004/07/06 11:44:36 fukuoka Exp $
=end

require 'kagemai/mode'
require 'kagemai/error'
require 'kagemai/cgi/action'
require 'kagemai/cgi/htmlhelper'
require 'kagemai/cgi/form_handler'

module Kagemai
  class DeleteProject < Action
    include AdminAuthorization
    include FormHandler

    STAGE_ACTION_MAP = {
      '0' => :make_delete_form, 
      '1' => :confirm_delete,
      '2' => :delete_project
    }

    def execute()
      check_authorization()
      init_form_handler()
      action_map = Hash.new(:invalid_stage).update(STAGE_ACTION_MAP)
      send(action_map[@cgi.get_param('s', '0')])
    end

    def make_delete_form(error = false)
      param = {:mode => @mode, :bts => @bts}
      body = eval_template('delete_project.rhtml', param)
      ActionResult.new(MessageBundle[:title_delete_project], 
                       header(), 
                       body, 
                       footer(), 
                       @css_url, 
                       @lang,
                       @charset)

    end

    def confirm_delete()
      init_project()
      param = {:mode => @mode, :project => @project}
      body = eval_template('delete_project_confirm.rhtml', param)
      ActionResult.new(MessageBundle[:title_delete_project_confirm], 
                       header(), 
                       body, 
                       footer(), 
                       @css_url, 
                       @lang,
                       @charset)

    end

    def delete_project()
      project_id = Util.untaint_path(@cgi.get_param('project'))
      confirm = @cgi.get_param('confirm')

      if confirm == 'yes' || confirm == 'yes_all' then
        delete_all = confirm == 'yes_all'
        project, del_name = @bts.delete_project(project_id, delete_all)

        param = {
          :mode       => @mode,
          :project    => project,
          :delete_all => delete_all,
          :del_name   => del_name
        }
        body = eval_template('delete_project_done.rhtml', param)
        ActionResult.new(MessageBundle[:title_delete_project_delete], 
                         header(), 
                         body, 
                         footer(), 
                         @css_url, 
                         @lang,
                         @charset)
      else
        make_delete_form()
      end
    end


    def invalid_stage()
      raise ParameterError, 'invalid parameter s'
    end

    def self.name()
      'delete_project'
    end
  end

end
