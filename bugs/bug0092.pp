{The unfixable bug. Maybe we get an idea when we keep looking at it.
 Daniel Mantione 5 februari 1998.}

const
        a:1..4=2;               {Crash 1.}
        b:set of 1..4=[2,3];    {Also crashes, but is the same bug.}

begin
end.
