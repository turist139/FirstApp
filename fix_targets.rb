require 'xcodeproj'

project_path = 'MyFocus.xcodeproj'
project = Xcodeproj::Project.open(project_path)

app_target = project.targets.find { |t| t.name == 'MyFocus' }
widget_target = project.targets.find { |t| t.name.include?('Widget') }

# We have files in the MyFocusWidgets group
widget_group = project.main_group.find_subpath('MyFocusWidgets', false) || project.main_group.children.find { |g| g.name == 'MyFocusWidgets' || g.path == 'MyFocusWidgets' }

files_to_remove = ['MyFocusWidgets.swift', 'MyFocusWidgetsBundle.swift', 'MyFocusWidgetsControl.swift', 'AppIntent.swift']
files_to_keep = ['MyFocusWidgets 2.swift', 'StreakWidget.swift', 'TimeRemainingWidget.swift']

# Remove from both targets' build phases
project.targets.each do |target|
  target.source_build_phase.files.each do |build_file|
    if build_file.file_ref
      file_name = build_file.file_ref.name || build_file.file_ref.path
      if files_to_remove.include?(file_name)
        build_file.remove_from_project
      elsif files_to_keep.include?(file_name)
        # Remove our custom files from main app target
        if target.name == 'MyFocus'
          build_file.remove_from_project
        end
      end
    end
  end
end

# Remove template file references from group
if widget_group
  widget_group.children.each do |child|
    name = child.name || child.path
    if files_to_remove.include?(name)
      child.remove_from_project
    end
  end
end

project.save
puts "Project saved successfully!"
