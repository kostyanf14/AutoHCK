# typed: false

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `activesupport` gem.
# Please instead update this file by running `bin/tapioca gem activesupport`.


class LoadError < ::ScriptError
  include ::DidYouMean::Correctable
end

class NameError < ::StandardError
  include ::ErrorHighlight::CoreExt
  include ::DidYouMean::Correctable
end
