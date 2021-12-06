require "option_parser"
require "json"
require "file_utils"

module ReflinkSnapshot
  extend self

  class Args
    property cmd = "", root_dir = "", path = "", snap_name = "", snaps_dir = Path.new(""), mountpoint = ""
  end

  def escape_slash(path)
    path.gsub("/", "%2F")
  end

  def file_snapshot(path, snap_path)
    Dir.mkdir_p(Path[snap_path].parent)
    stderr = IO::Memory.new
    args = ["--reflink=always", "--preserve=all", path.to_s, snap_path.to_s]
    status = Process.run("cp", args: args, error: stderr)
    command_error "Snapshot create failed (#{stderr.to_s.strip})" unless status.success?
  end

  def directory_snapshot(path, snap_path)
    Dir.children(path).each do |entry|
      full_path = Path.new(path, entry)
      snap_full_path = Path.new(snap_path, entry)
      if File.directory?(full_path)
        directory_snapshot(full_path, snap_full_path)
      else
        file_snapshot(full_path, snap_full_path)
      end
    end
  end

  def rollback_snapshot(args)
    full_path = Path.new(args.root_dir, args.path).to_s
    full_path_tmp = full_path + ".#{Time.utc.to_unix}"
    snap_path = Path.new(args.snaps_dir, args.snap_name).to_s

    File.rename(full_path, full_path_tmp)
    File.rename(snap_path, full_path)
    FileUtils.rm_rf(full_path_tmp)

    puts "Snapshot rollback successful"
  end

  def delete_snapshot(args)
    snap_path = Path.new(args.snaps_dir, args.snap_name)

    command_error "Snapshot #{args.snap_name} doesn't exists" unless File.exists?(snap_path)
    FileUtils.rm_rf(snap_path)

    puts "Snapshot deleted successfully"
  end

  def create_snapshot(args)
    full_path = Path.new(args.root_dir, args.path)
    snap_path = Path.new(args.snaps_dir, args.snap_name)

    command_error "Snapshot #{args.snap_name} already exists" if File.exists?(snap_path)

    if File.directory?(full_path)
      directory_snapshot(full_path, snap_path)
    else
      file_snapshot(full_path, snap_path)
    end

    puts "Snapshot created successfully"
  end

  def mount_snapshot(args)
    snap_path = Path.new(args.snaps_dir, args.snap_name)

    stderr = IO::Memory.new
    cmd_args = ["--bind", snap_path.to_s, args.mountpoint]
    puts ["mount", "--bind", snap_path.to_s, args.mountpoint]
    status = Process.run("mount", args: cmd_args, error: stderr)
    command_error "Failed to mount the Snapshot (#{stderr.to_s.strip})" unless status.success?
  end

  def list_snapshots(args)
    snaps = [] of String

    command_error("No Snapshots", 0) unless File.exists?(args.snaps_dir)

    if args.path != ""
      Dir.children(args.snaps_dir).each do |snap|
        suffix = File.directory?(Path.new(args.snaps_dir, snap)) ? "(directory)" : "(file)"
        snaps << "#{args.snaps_dir.basename.gsub("%2F", "/")}@#{snap} #{suffix}"
      end
    else
      Dir.children(args.snaps_dir).each do |dir|
        snaps_dir = Path.new(args.snaps_dir, dir)
        Dir.children(snaps_dir).each do |snap|
          suffix = File.directory?(Path.new(snaps_dir, snap)) ? "(directory)" : " (file)"
          snaps << "#{dir.gsub("%2F", "/")}@#{snap} #{suffix}"
        end
      end
    end

    snaps.each do |snap|
      puts snap
    end
  end

  def command_error(msg, code = 1)
    STDERR.puts msg
    exit code
  end

  def parse_args
    args = Args.new

    parser = OptionParser.new do |parser|
      parser.banner = "Usage: reflink-snapshot [subcommand] [arguments]"
      parser.on("create", "Create a Reflink Snapshot") do
        parser.banner = "Usage: reflink-snapshot create ROOT_DIR PATH@SNAP_NAME [arguments]"
        args.cmd = "create"
      end
      parser.on("list", "List Reflink Snapshots") do
        parser.banner = "Usage: reflink-snapshot list ROOT_DIR PATH [arguments]"
        args.cmd = "list"
      end
      parser.on("delete", "Delete a Reflink Snapshot") do
        parser.banner = "Usage: reflink-snapshot delete ROOT_DIR PATH@SNAP_NAME [arguments]"
        args.cmd = "delete"
      end
      parser.on("rollback", "Rollback a Reflink Snapshot") do
        parser.banner = "Usage: reflink-snapshot rollback ROOT_DIR PATH@SNAP_NAME [arguments]"
        args.cmd = "rollback"
      end
      parser.on("mount", "Mount a Directory Snapshot") do
        parser.banner = "Usage: reflink-snapshot mount ROOT_DIR PATH@SNAP_NAME [arguments]"
        args.cmd = "mount"
      end
      parser.on("-h", "--help", "Show this help") do
        puts parser
        exit
      end

      parser.invalid_option do |flag|
        STDERR.puts parser
        command_error "ERROR: #{flag} is not a valid option."
      end

      parser.unknown_args do |pargs|
        args.root_dir = pargs[0] if pargs.size > 0
        args.path, _, args.snap_name = pargs[1].partition("@") if pargs.size > 1
        args.mountpoint = pargs[2] if pargs.size > 2

        command_error "Root directory is not provided" if args.root_dir == ""
        command_error "File or Directory path not provided" if args.path == "" && args.cmd != "list"
        command_error "Snapshot name not provided" if args.snap_name == "" && args.cmd != "list"
        command_error "Mountpoint not provided" if args.mountpoint == "" && args.cmd == "mount"
      end
    end

    parser.parse

    args
  end

  def run
    args = parse_args

    # Remove the root dir from the path if it is passed.
    args.path = args.path.sub(Regex.new("^#{args.root_dir.rstrip("/")}/"), "")

    full_path = Path.new(args.root_dir, args.path)
    command_error "File/Directory(#{full_path}) not exists" unless File.exists?(full_path)

    if args.path == ""
      args.snaps_dir = Path.new(args.root_dir, ".snaps")
    else
      args.snaps_dir = Path.new(args.root_dir, ".snaps", args.path.gsub("/", "%2F"))
    end

    case args.cmd
    when "create"   then create_snapshot(args)
    when "list"     then list_snapshots(args)
    when "delete"   then delete_snapshot(args)
    when "rollback" then rollback_snapshot(args)
    when "mount"    then mount_snapshot(args)
    else
      command_error "Invalid command \"#{args.cmd}\""
    end
  end
end

ReflinkSnapshot.run
