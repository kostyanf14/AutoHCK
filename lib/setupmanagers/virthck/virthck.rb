# frozen_string_literal: true

require 'English'
require './lib/exceptions'
require './lib/auxiliary/json_helper'
require './lib/auxiliary/host_helper'

# AutoHCK module
module AutoHCK
  # Virthck class
  class VirtHCK
    include Helper

    attr_reader :kit

    VIRTHCK_CONFIG_JSON = 'lib/setupmanagers/virthck/virthck.json'
    STUDIO = 'st'
    DEFAULT_RUN_OPTIONS = {
      first_time: false,
      studio_snapshot: true,
      studio_iso_list: [],
      clients_snapshot: true,
      clients_iso_list: []
    }.freeze

    def initialize(project)
      @project = project
      @logger = project.logger
      @config = read_json(VIRTHCK_CONFIG_JSON, @logger)
      @driver = project.engine.driver
      @device = @driver&.dig('device')
      @platform = project.engine.platform
      @workspace_path = project.workspace_path
      @id = project.id
      @kit = @platform['kit']
      @run_options = DEFAULT_RUN_OPTIONS
    end

    def studio_snapshot
      filename = File.basename(@platform['st_image'], '.*')
      "#{@workspace_path}/#{filename}-snapshot.qcow2"
    end

    def studio_image
      if @run_options[:studio_snapshot]
        studio_snapshot
      else
        "#{@config['images_path']}/#{@platform['st_image']}"
      end
    end

    def create_studio_image
      cmd = [
        "#{@config['qemu_img']} create -f qcow2",
        "#{@config['images_path']}/#{@platform['st_image']}",
        '300G'
      ]
      run_cmd(cmd)
    end

    def client_snapshot(name)
      filename = File.basename(@platform['clients'][name]['image'], '.*')
      "#{@workspace_path}/#{filename}-snapshot.qcow2"
    end

    def client_image(name)
      if @run_options[:clients_snapshot]
        client_snapshot(name)
      else
        "#{@config['images_path']}/#{@platform['clients'][name]['image']}"
      end
    end

    def create_client_image(name)
      cmd = [
        "#{@config['qemu_img']} create -f qcow2",
        "#{@config['images_path']}/#{@platform['clients'][name]['image']}",
        '300G'
      ]
      run_cmd(cmd)
    end

    def platform_config(param)
      default_value = @config['platforms_defaults'][param]
      @platform[param] || default_value
    end

    def driver_platform_config(param)
      default_value = platform_config(param)
      return default_value if @driver.nil?

      @driver[param] || default_value
    end

    def studio_iso_cmd
      drive_cmd = []

      @run_options[:studio_iso_list].each do |iso|
        iso_path = Pathname.new(@project.config['iso_path']).join(iso)
        drive_cmd += ["-drive file=#{iso_path},media=cdrom,readonly=on"]
      end

      drive_cmd.empty? ? [] : ['-st_extra', "'#{drive_cmd.join(' ')}'"]
    end

    def client_iso_cmd(name)
      drive_cmd = []

      @run_options[:clients_iso_list].each do |iso|
        iso_path = Pathname.new(@project.config['iso_path']).join(iso)
        drive_cmd += ["-drive file=#{iso_path},media=cdrom,readonly=on"]
      end

      drive_cmd.empty? ? [] : ["-#{name}_extra", "'#{drive_cmd.join(' ')}'"]
    end

    def base_cmd
      ["cd #{@config['virthck_path']} &&",
       "sudo ./hck.sh ci_mode -id #{@id}",
       "-world_bridge #{@config['dhcp_bridge']}",
       "-qemu_bin #{@config['qemu_bin']}",
       "-ivshmem_server_bin #{@config['ivshmem_server_bin']}",
       "-fs_deamon_bin #{@config['fs_deamon_bin']}",
       "-filesystem_tests_image #{@config['filesystem_tests_image']}",
       "-ctrl_net_device #{platform_config('ctrl_net_device')}",
       "-world_net_device #{platform_config('world_net_device')}",
       "-viommu #{platform_config('viommu')}",
       "-st_image #{studio_image}"] + studio_iso_cmd
    end

    def device_cmd
      if @device.nil?
        []
      else
        ["-device_type #{@device['type']}",
         @device['name'].empty? ? '' : "-device_name #{@device['name']}",
         @device['extra'].empty? ? '' : "-device_extra #{@device['extra']}"]
      end
    end

    def platform_cmd
      ["-machine_type #{platform_config('machine_type')}",
       "-s3 #{platform_config('s3')}",
       "-s4 #{platform_config('s4')}",
       "-enlightenments_state #{driver_platform_config('enlightenments_state')}",
       "-vhost_state #{platform_config('vhost_state')}"]
    end

    def client_cmd(name, client)
      ["-#{name}_image #{client_image(name)}",
       "-#{name}_memory #{client['memory']}",
       "-#{name}_cpus #{client['cpus']}"] + client_iso_cmd(name)
    end

    def clients_cmd
      clients = []
      @platform['clients'].each do |name, client|
        clients += client_cmd(name, client)
      end
      clients
    end

    def retrieve_pid(pid_file)
      Timeout.timeout(5) do
        sleep 1 while File.zero?(pid_file.path)
      end
      pid_file.read.strip.to_i
    rescue Timeout::Error
      nil
    end

    def validate_run_opts(run_opts)
      extra_keys = (run_opts.keys - DEFAULT_RUN_OPTIONS.keys)

      raise(SetupManagerError, "Undefined run options: #{extra_keys.join(', ')}.") unless extra_keys.empty?

      DEFAULT_RUN_OPTIONS.merge(run_opts)
    end

    def execute_run(name)
      temp_file do |pid|
        cmd = base_cmd + clients_cmd + device_cmd + platform_cmd +
              ["-pidfile #{pid.path}", name]
        create_command_file(cmd.join(' '), name) if @run_options[:first_time]
        run_cmd(cmd)
        retrieve_pid(pid)
      end
    end

    def run(name, run_opts = {})
      @run_options = validate_run_opts(run_opts)
      @logger.debug(@run_options)
      validate_paths(name)

      sleep(rand(10))
      execute_run(name)
    end

    def close
      @logger.info('Cleanup host configurations')
      cmd = base_cmd + device_cmd + ['end']
      run_cmd(cmd)
    end

    def create_client_snapshot(name)
      client = @platform['clients'][name]
      @logger.info("Creating #{client['name']} snapshot file")
      base = "#{@config['images_path']}/#{client['image']}"
      target = client_snapshot(name)
      create_snapshot_cmd(base, target)
    end

    def delete_client_snapshot(name)
      client = @platform['clients'][name]
      @logger.info("Deleting #{client['name']} snapshot file")
      target = client_snapshot(name)
      FileUtils.rm_f(target)
    end

    def create_studio_snapshot
      @logger.info('Creating studio snapshot file')
      base = "#{@config['images_path']}/#{@platform['st_image']}"
      target = studio_snapshot
      create_snapshot_cmd(base, target)
    end

    def delete_studio_snapshot
      @logger.info('Deleting studio snapshot file')
      target = studio_snapshot
      FileUtils.rm_f(target)
    end

    def create_snapshot_cmd(base, target)
      cmd = ["#{@config['qemu_img']} create -f qcow2 -F qcow2 -b", base, target]
      run_cmd(cmd)
    end

    def create_command_file(cmd, filename)
      path = "#{@workspace_path}/#{filename}.sh"
      File.open(path, 'w') { |file| file.write(cmd) }
      FileUtils.chmod('+x', path)
    end

    def normalize_paths
      @config['images_path'].chomp!('/')
      @config['virthck_path'].chomp!('/')
    end

    def check_studio_image_exist
      File.exist?("#{@config['images_path']}/#{@platform['st_image']}")
    end

    def check_client_image_exist(name)
      client = @platform['clients'][name]
      File.exist?("#{@config['images_path']}/#{client['image']}")
    end

    def validate_images(name)
      if name == STUDIO
        unless check_studio_image_exist
          @logger.fatal('Studio image not found')
          raise InvalidPathError
        end
      else
        client = @platform['clients'][name]
        unless check_client_image_exist(name)
          @logger.fatal("#{client['name']} image not found")
          raise InvalidPathError
        end
      end
    end

    def validate_iso_list(iso_list)
      iso_list.each do |iso|
        iso_path = Pathname.new(@project.config['iso_path']).join(iso)
        unless File.exist?(iso_path)
          @logger.fatal("ISO #{iso_path} not found")
          raise InvalidPathError
        end
      end
    end

    def validate_iso(name)
      if name == STUDIO
        validate_iso_list(@run_options[:studio_iso_list])
      else
        validate_iso_list(@run_options[:clients_iso_list])
      end
    end

    def create_studio
      studio_ip = @project.config['ip_segment'] + @project.id.to_str
      @studio = HCKStudio.new(@project, self, STUDIO, studio_ip)
    end

    def create_client(tag, name)
      HCKClient.new(@project, self, @studio, tag, name)
    end

    def validate_paths(name)
      normalize_paths
      validate_images(name)
      validate_iso(name)
      return if File.exist?("#{@config['virthck_path']}/hck.sh")

      @logger.fatal('VirtHCK path is not valid')
      raise InvalidPathError
    end
  end
end
