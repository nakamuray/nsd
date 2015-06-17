require "gtk3"

class NSD
    def main
        @io = GLib::IOChannel.new($stdin)
        watch1 = @io.add_watch(GLib::IOChannel::IN) do |io, cond|
            line = io.readline().strip()
            y = 50 + rand * (Gdk::default_root_window.screen.height - 100)
            Comment.new(line).start(y)
        end
        watch2 = @io.add_watch(GLib::IOChannel::HUP) do |io, cond|
            io.close()
            GLib::Source.remove(watch1)
            GLib::Source.remove(watch2)
        end

        Gtk::main()
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
    @@font = "Migu 1P bold 24"
    @@fps = 60
    @@duration = 10

    def initialize(msg)
        super()

        @msg = msg
        @label = Gtk::Label.new(msg)
        @label.override_font(Pango::FontDescription.new(@@font))
        @label.override_color(0, Gdk::RGBA.new(1.0, 1.0, 1.0, 1.0))
        @label.signal_connect("draw") do |label, cr|
            on_draw_outline_text(cr)
        end

        add(@label)
    end
    def on_draw_outline_text(cr)
        # clean
        cr.set_source_rgba(0.0, 0.0, 0.0, 0.0)
        cr.set_operator(Cairo::OPERATOR_SOURCE)
        cr.paint()

        layout = cr.create_pango_layout()
        layout.set_font_description(Pango::FontDescription.new(@@font))
        layout.text = @msg
        cr.pango_layout_path(layout)

        cr.set_source_rgba(1.0, 1.0, 1.0, 1.0)
        cr.fill_preserve()

        cr.set_source_rgba(0.0, 0.0, 0.0, 1.0)
        cr.set_line_width(1.0)
        cr.stroke()
    end
    def start(y)
        @y = y
        @x = screen.width
        move(@x, @y)
        show_all()
        step = (@x + size[0]) / (@@duration * @@fps)
        @timeout_id = GLib::Timeout.add(1000.0/@@fps) do
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
