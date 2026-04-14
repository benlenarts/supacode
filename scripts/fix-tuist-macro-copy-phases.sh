#!/usr/bin/env bash
set -euo pipefail

root="${1:-Tuist/.build/tuist-derived}"

if [ ! -d "${root}" ]; then
  exit 0
fi

while IFS= read -r -d '' project_file; do
  ruby - "${project_file}" <<'RUBY'
path = ARGV.fetch(0)
contents = File.read(path)
updated = contents.gsub(/cp -f \\"\$BUILD_DIR\/\$CONFIGURATION\/([^"]+)\\" \\"\$BUILD_DIR\/Debug\$EFFECTIVE_PLATFORM_NAME\/\1\\"\\nfi/) do
  macro = Regexp.last_match(1)
  "if [[ \\\"$BUILD_DIR/$CONFIGURATION/#{macro}\\\" != \\\"$BUILD_DIR/Debug$EFFECTIVE_PLATFORM_NAME/#{macro}\\\" ]]; then\\n        cp -f \\\"$BUILD_DIR/$CONFIGURATION/#{macro}\\\" \\\"$BUILD_DIR/Debug$EFFECTIVE_PLATFORM_NAME/#{macro}\\\"\\n    fi\\nfi"
end
File.write(path, updated) unless updated == contents
RUBY
done < <(find "${root}" -path '*/project.pbxproj' -print0)
