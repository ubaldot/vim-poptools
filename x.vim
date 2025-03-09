vim9script

import autoload './habamax_popup.vim'

habamax_popup.Select("Echo Text",
           ["He was aware there were numerous wonders of this world including the",
            "unexplained creations of humankind that showed the wonder of our",
            "ingenuity. There are huge heads on Easter Island. There are the",
            "Egyptian pyramids. There's Stonehenge. But he now stood in front of a",
            "newly discovered monument that simply didn't make any sense and he",
            "wondered how he was ever going to be able to explain it.",
            "The wave crashed and hit the sandcastle head-on. The sandcastle began",
            "to melt under the waves force and as the wave receded, half the",
            "sandcastle was gone. The next wave hit, not quite as strong, but still",
            "managed to cover the remains of the sandcastle and take more of it",
            "away. The third wave, a big one, crashed over the sandcastle completely",
            "covering and engulfing it. When it receded, there was no trace the",
            "sandcastle ever existed and hours of hard work disappeared forever." ],
           (res, key) => {
              echo res
           })
