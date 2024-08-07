# frozen_string_literal: true

# AutoHCK module
module AutoHCK
  # A custom SetupManager error exception
  class SetupManagerError < AutoHCKError; end

  # A custom StudioConnect error exception
  class StudioConnectError < AutoHCKError; end

  # custom machine error
  class MachineError < AutoHCKError; end

  class MachinePidNil < MachineError; end

  class MachineRunError < MachineError; end

  # custom client error
  class ClientError < MachineError; end

  class ClientRunError < ClientError; end
end
