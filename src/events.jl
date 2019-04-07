# Hooks and event loop functionality

struct KeyEvent
    spec::AbstractString
end

import Base: ==
==(e1::KeyEvent, e2::KeyEvent) = e1.spec == e2.spec

struct CursorPosition
    pos::SVector{3,Float64}
end

_eventspec_str(s::AbstractString) = s
_eventspec_str(e::KeyEvent) = "key:$(e.spec)"

_argspec_str(s::AbstractString) = s
_argspec_str(::Type{Nothing}) = "null"
_argspec_str(::Type{CursorPosition}) = "cursor"


"""
    event_loop(callback::Function, [plotobj::DisplazWindow], event_list...)

Subscribe to a list of events, calling `callback` each time one is received.

Each event comes with some optional some state which is attached at the time
the event is triggered.  The events are specified as a list of `event=>state`
pairs.

Currently only `KeyEvent` is supported, with the possible arguments `Nothing` or
`CursorPosition`.  For example:

```
Displaz.event_loop(
        KeyEvent("c")=>Nothing,
        KeyEvent("p")=>CursorPosition
) do event, arg
    @show event, arg
    if event == KeyEvent("c")
        clearplot()
    end
end
```
"""
function event_loop(callback::Function, plotobj::DisplazWindow, event_list...)
    hookopts = [["-hook", _eventspec_str(e), _argspec_str(p)]
                for (e,p) in event_list]
    stdout,stdin,proc = readandwrite(`$_displaz_cmd -server $(plotobj.name) $(vcat(hookopts...))`)
    while true
        rawline = readline(stdout)
        line = split(rawline)
        if length(line) < 2
            warn("Unrecognized displaz hook string: \"$line\"")
            break
        end
        eventspec = line[1]
        if startswith(eventspec, "key:")
            event = KeyEvent(eventspec[5:end])
        else
            warn("Unrecognized displaz event type: \"$eventspec\"")
            event = eventspec
        end
        argspec = line[2]
        if argspec == "null"
            arg = :nothing
        elseif argspec == "cursor"
            arg = CursorPosition(map(s->parse(Float64,s), line[3:end]))
        else
            warn("Unrecognized displaz hook payload: \"$argspec\"")
            arg = line[3:end]
        end
        callback(event, arg) != false || break
    end
    kill(proc)
end

event_loop(callback::Function, event_list...) = event_loop(callback, current(), event_list...)

# Wait until the given displaz event occurs
Base.wait(event::KeyEvent) = event_loop((e,a)->false, event=>Nothing)
