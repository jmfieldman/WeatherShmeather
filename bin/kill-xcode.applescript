on run argv
  if (count argv) < 1 then
    log "Must pass in the absolute project path as first argument"
  end if
  set projectPath to (item 1 of argv)

  if (application "Xcode" is running) then
    tell application "Xcode"
      set all to get every window
      repeat with xcodeproj in all
        set doc to document of xcodeproj
        if doc is not missing value then
          if (path of doc is projectPath) then
            close xcodeproj
            return true
          end if
        end if
      end repeat
    end tell
  end if
end run
