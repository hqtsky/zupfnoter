# todo: remove redefinintion of Native


module ABC2SVG


  # this class wraps abc2svg for zupfnoter
  # it has two modes
  #    :svg - render an svg image
  #    :model - do not render but update the abc-model
  #
  #    these two modes are for preparation of performance issues
  #    in case the model extractor is too slow
  #
  #    todo: remove dependency on DOM
  #
  class Abc2Svg


    def initialize(div, options={mode: :svg})
      @on_select           = lambda { |element|}
      @printer             = div
      @svgbuf              = []
      @abc_source          = ''
      @element_to_position = {} # mapping svg elements to position
      @abc_model           = nil
      @object_map          = {} # mapping objects to their Id

      @user = {img_out:     nil,
               errmsg:      nil,
               read_file:   nil,
               annotate:    true,
               page_format: true,
               keep_remark: true
      }


      set_callback(:errmsg) do |message, line_number, column_number|
        #todo handle produce startpos / endpos
        $log.error(message, [line_number+1, column_number+1])
      end


      case options[:mode]

        when :svg

          set_callback(:anno_start) do |type, start, stop, x, y, w, h|
            _anno_start(type, start, stop, x, y, w, h)
          end

          set_callback(:anno_stop) do |type, start, stop, x, y, w, h|
            _anno_stop(type, start, stop, x, y, w, h)
          end

          set_callback(:img_out) do |svg|
            @svgbuf.push svg
          end

          set_callback(:get_abcmodel) do |tsfirst, voice_tb, anno_type, info|
            # _get_abcmodel(tsfirst, voice_tb, anno_type)
          end

        when :model
          set_callback(:get_abcmodel) do |tsfirst, voice_tb, anno_type, info|
            _callback_get_abcmodel(tsfirst, voice_tb, anno_type, info)
          end

        else
          $log.error("BUG: unsupported mode for abc2svg")
      end

      @root = %x{new Abc(#{@user.to_n})}
    end

    # Highligh routines.

    # highlight a renge in the SVG
    # todo: we might need to
    def range_highlight(from, to)
      unhighlight_all()
      range_highlight_more(from, to)
      nil
    end

    def range_highlight_more(from, to)
      get_elements_by_range(from, to).each do |id|
        element = Element.find("##{id}")

        %x{#{element}.parents('svg').get(0).scrollIntoView()}
        classes = [element.attr('class').split(" "), 'highlight'].flatten.uniq.join(" ")
        element.attr('class', classes)
      end
      nil
    end

    def range_unhighlight_more(from, to)
      get_elements_by_range(from, to).each do |id|
        foo     = Element.find("##{id}")
        classes = foo.attr('class').gsub("highlight", '')
        foo.attr('class', classes)
      end
    end

    def unhighlight_all()
      Element.find('.highlight').attr('class', 'abcref')
    end


    def on_select(&block)
      @on_select = block
      _set_on_select()
    end

    def draw(abc_code)
      @abc_source          = abc_code
      @element_to_position = {}
      @svgbuf              = []
      %x{
      #{@root}.tosvg(#{"abc"}, #{@abc_source});
      }

      @printer.html(get_svg())
      _set_on_select();
      nil
    end

    def get_abcmodel(abc_code)
      %x{#{@root}.tosvg("abc", #{abc_code})};
      @abc_model
    end

    # todo: mke private or even remove?
    def get_svg
      @svgbuf.join("\n")
    end


    # todo: make private
    def set_callback(event, &block)
      @user[event] = block;
    end


    def get_elements_by_range(from, to)
      range  = [from, to].sort
      result = []
      @element_to_position.each { |k, value|
        noterange = [:startChar, :endChar].map { |c| value[c] }.sort

        if (range.first - noterange.last) * (noterange.first - range.last) > 0
          result.push(k)
        end
      }
      result
    end

    private
    # This is the business logic to copy the abc-model
    # This method is registered as callback to abc2svg
    #
    # we use gen_json in to prepare
    #
    def _callback_get_abcmodel(tsfirst, voice_tb, music_types, info)

      json_model = ""
      %x{
          abcmidi = new AbcMIDI();
          abcmidi.add(#{tsfirst}, #{voice_tb}[0].key);
          to_json = new AbcJSON();
          #{json_model} =  to_json.gen_json(#{tsfirst}, #{voice_tb}, #{music_types}, #{info});
      }

      @abc_model = JSON.parse(json_model)

      if $log.loglevel == "debug"
        $log.debug(@abc_model.to_json)
      end
      @abc_model
    end


    # this is a backconvert from line / colun - info provided
    # by abc2svg in case of errors
    def _get_charpos(abc_source, line, column)
      lines  = @abc_source.split("\n")
      result = lines[0 .. line].inject(0) { |r, v| r += v.length }
      result + column
    end

    ## here we have the business logic of annotations
    # such that is fulfils the needs of zupfnoter cross - highlighting
    def _anno_start(music_type, start_offset, stop_offset, x, y, w, h)
      id = _mk_id(music_type, start_offset, stop_offset)
      %x{
      #{@root}.out_svg('<g class="' + #{id} +'">\n')
      }
    end


    def _anno_stop(music_type, start_offset, stop_offset, x, y, w, h)
      id = _mk_id(music_type, start_offset, stop_offset)
      %x{
          // close the container
          #{@root}.out_svg('</g>\n');
          // create a rectangle
          #{@root}.out_svg('<rect class="abcref" id="' + #{id} +'" x="');
          #{@root}.out_sxsy(#{x}, '" y="', #{y});
          #{@root}.out_svg('" width="' + #{w}.toFixed(2) +
            '" height="' + #{h}.toFixed(2) + '"/>\n')
        }
      @element_to_position[id] = {startChar: start_offset, endChar: stop_offset}

    end


    def _mk_id(music_type, start_offset, end_offset)
      "_#{music_type}_#{start_offset}_#{end_offset}_"
    end


    def _set_on_select()
      Element.find('.abcref').on(:click) do |evt|
        evt.stop_propagation
        @on_select.call(@element_to_position[evt.current_target.id])
        nil
      end
    end

  end
end