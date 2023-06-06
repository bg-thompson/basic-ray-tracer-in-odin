package weekend

import f "core:fmt"
import s "core:strings"
import   "core:unicode/utf8"

// Draw a progress bar given a fraction of completion.
// Remember: The returned string will be CALLED BY PRINTF().
make_progress_bar :: proc( r : f64) -> string {
    assert(0 <= r && r <= 1)
    BAR_LENGTH                  :: 40
    bar_runes := make([]rune, BAR_LENGTH + 3)
    
    PROGRESS_CHAR               :: '='
    bar_runes[0]                = '\r'
    bar_runes[1]                = '['
    bar_runes[BAR_LENGTH + 2]   = ']'

    progress_length := int(r * f64(BAR_LENGTH))

    // Draw bar.
    for i in 2..<progress_length+2 {
        bar_runes[i] = PROGRESS_CHAR
    }
    for i in progress_length+2..<BAR_LENGTH+2 {
        bar_runes[i] = ' '
    }
    // Write percentage done value.
    // NOTE: Since %% is crappy printf syntax for the char %, and printf
    // calls the returned string, we need to write two %% signs in the return string.
    bar_center_index :: BAR_LENGTH / 2 + 2
    pc := int(r * 100)
    pcs := f.tprintf("%d%%%%", pc)
    for r, i in pcs {
        bar_runes[bar_center_index - 1 + i] = r
    }
    bar := utf8.runes_to_string(bar_runes)
    return bar
}
