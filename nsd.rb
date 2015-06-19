require "gtk3"
require "json"
require "optparse"

class NSD
    def main
        options = parse_options(ARGV)

        io = GLib::IOChannel.new($stdin)
        watch_id = io.add_watch(GLib::IOChannel::IN) do |io, cond|
            begin
                line = io.readline().strip()
            rescue EOFError
                io.close()
                GLib::Source.remove(watch_id)
                return
            end
            if line == ""
                next true
            end
            if options.json
                begin
                    line = JSON::load(line)
                rescue JSON::ParserError => e
                    warn e
                    next true
                end
            end
            attrs = nil
            if options.markup
                begin
                    attrs, line = Pango::parse_markup(line)
                rescue GLib::Error => e
                    warn e
                    next true
                end
            end
            y = 50 + rand * (Gdk::default_root_window.screen.height - 100)
            Comment.new(
                line, attrs=attrs, font=options.font, duration=options.duration
            ).start(y)
        end

        Gtk::main()
    end

    def parse_options(argv)
        options = OpenStruct.new()
        options.duration = Comment::DURATION
        options.font = Comment::FONT
        options.json = false
        options.markup = false

        OptionParser.new do |opts|
            opts.banner = "Usage: #{$0} [options]"

            opts.on("-d", "--duration N", Float,
                    "duration of displaying comment",
                    "(default: #{options.duration})") do |d|
                options.duration = d
            end

            opts.on("-f", "--font FONT",
                    "display font", "(default: #{options.font})") do |f|
                options.font = f
            end

            opts.on("-j", "--json",
                    "parse line as JSON", "(default: #{options.json})") do |j|
                options.json = j
            end

            opts.on("-m", "--markup",
                    "parse line pango markup", "(default: #{options.markup})") do |m|
                options.markup = m
            end
        end.parse!(argv)

        return options
    end
end

class TransparentWindow < Gtk::Window
    def initialize
        super(Gtk::Window::Type::POPUP)

        input_pass_through()
        make_transparent()
    end
    def input_pass_through
        region = Cairo::Region.new([0, 0, 1, 1])
        input_shape_combine_region(nil)
        input_shape_combine_region(region)
    end
    def make_transparent
        visual = screen.rgba_visual
        if screen.composited?
            set_visual(visual)
        end
        override_background_color(0, Gdk::RGBA.new(1.0, 1.0, 1.0, 0.0))
    end
end

class Comment < TransparentWindow
    FONT = "Migu 1P bold 24"
    FPS = 60
    DURATION = 10

    def initialize(msg, attrs=nil, font=nil, duration=nil)
        super()

        @msg = msg
        @font = font || FONT
        @duration = duration || DURATION

        @label = Gtk::Label.new(msg)
        @label.attributes = attrs
        @label.override_font(Pango::FontDescription.new(@font))
        @label.override_color(0, Gdk::RGBA.new(1.0, 1.0, 1.0, 1.0))
        @label.signal_connect_after("draw") do |label, cr|
            on_draw_outline_text(cr)
        end

        add(@label)
    end
    def on_draw_outline_text(cr)
        layout = cr.create_pango_layout()
        layout.set_font_description(Pango::FontDescription.new(@font))
        layout.text = @msg
        layout.attributes = @label.attributes
        cr.pango_layout_path(layout)

        cr.set_source_rgba(0.0, 0.0, 0.0, 1.0)
        cr.set_line_width(1.0)
        cr.stroke()
    end
    def start(y)
        @y = y
        @x = screen.width
        move(@x, @y)
        show_all()
        step = Float(@x + size[0]) / (@duration * FPS)
        @timeout_id = GLib::Timeout.add(1000.0/FPS) do
            move_next(step)
        end
    end
    def move_next(step)
        move(@x, @y)
        @x -= step

        if @x <= -size[0]
            GLib::Source.remove(@timeout_id)
            @timeout_id = nil
            destroy()
        else
            true
        end
    end
end

NSD.new().main()
