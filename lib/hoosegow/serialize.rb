require 'json'
require 'stringio'

class Hoosegow
  module Serialize
    def dump_method_call(name, args)
      args, files = dump_object args
      data = JSON.dump "name" => name, "args" => args
      data += "\n"
      files.each do |f|
        data << f
      end
      data
    end

    def read_method_call(pipe)
      data = JSON.load pipe.readline
      data["args"] = load_object data["args"], pipe
      data
    end

    private
    def dump_object(object)
      case object
      when Array
        dump_array object
      when Hash
        dump_hash object
      when File
        dump_file object
      else
        [object, []]
      end
    end

    def dump_array(array)
      rval  = []
      files = []
      array.each do |a|
        r,f = dump_object a
        rval  << r
        files += f
      end
      [rval, files]
    end

    def dump_hash(hash)
      rval  = {}
      files = []
      hash.each do |k,v|
        r,f = dump_object v
        rval[k] = r
        files += f
      end
      [rval, files]
    end

    def dump_file(file)
      [{:_hoosegow_file => file.size}, [file.read]]
    end

    def load_object(object, pipe)
      case object
      when Array
        load_array object, pipe
      when Hash
        if object.key? :_hoosegow_file
          load_file object, pipe
        else
          load_hash object, pipe
        end
      else
        object
      end
    end

    def load_array(array, pipe)
      array.map do |a|
        load_object a, pipe
      end
    end

    def load_hash(hash, pipe)
      rval = {}
      hash.map do |k,v|
        rval[k] = load_object v, pipe
      end
      rval
    end

    def load_file(file, pipe)
      size = file[:_hoosegow_file]
      StringIO.new pipe.read(size)
    end
  end
end
