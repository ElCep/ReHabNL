; File: models/ReHab.nlogo
extensions [csv]

breed [households household]

globals [
  round-number
  max-rounds
  total-harvesters
  protected-area-limit
  communication?
  ranger-strategy
  protected-area-compliance
  poacher-share
  coordination-strength
  initial-biomass-level
  use-paper-initial-map?
  cumulative-harvest
  cumulative-newborns
  total-biomass
  trajectory-data
  current-protected-ids
]

patches-own [
  cell-id
  biomass
  protected?
  nesting?
  newborns-last-round
  previous-newborns
  harvested-this-round?
  harvested-last-round?
  harvested-two-rounds-ago?
  scheduled-households
]

households-own [
  hid
  strategy
  harvest-total
  harvest-last-round
]

to setup
  clear-all
  setup-defaults
  resize-world 0 4 0 3
  set-patch-size 45
  setup-patches
  setup-households
  reset-metrics
  reset-ticks
end

to setup-defaults
  if not is-number? max-rounds [ set max-rounds 5 ]
  if not is-number? household-count [ set household-count 5 ]
  if not is-number? protected-area-limit [ set protected-area-limit 3 ]
  if not is-number? harvesters-per-household [ set harvesters-per-household 4 ]
  if not is-number? protected-area-compliance [ set protected-area-compliance 0.85 ]
  if not is-number? poacher-share [ set poacher-share 0.30 ]
  if not is-number? coordination-strength [ set coordination-strength 0.90 ]
  if not is-number? initial-biomass-level [ set initial-biomass-level 30 ]
  if not is-boolean? communication? [ set communication? false ]
  if household-strategy-mode = 0 [ set household-strategy-mode "mixed" ]
  if ranger-strategy = 0 [ set ranger-strategy "manager" ]
  if not is-boolean? use-paper-initial-map? [ set use-paper-initial-map? true ]
  set total-harvesters household-count * harvesters-per-household
end

to setup-patches
  ask patches [
    set cell-id patch-id pxcor pycor
    set biomass 0
    set protected? false
    set nesting? false
    set newborns-last-round 0
    set previous-newborns 0
    set harvested-this-round? false
    set harvested-last-round? false
    set harvested-two-rounds-ago? false
    set scheduled-households []
    set plabel-color black
  ]

  if use-paper-initial-map? [
    setup-paper-initial-map
  ]
  if not use-paper-initial-map? [
    setup-generated-initial-map
  ]

  recolor-patches
  update-patch-labels
end

to setup-paper-initial-map
  let initial-map [
    [1 1] [2 1] [3 2] [4 1] [5 1]
    [6 2] [7 0] [8 2] [9 3] [10 2]
    [11 1] [12 3] [13 1] [14 2] [15 1]
    [16 1] [17 3] [18 1] [19 0] [20 2]
  ]
  foreach initial-map [
    pair ->
    ask patch-from-id (item 0 pair) [
      set biomass item 1 pair
    ]
  ]
end

to setup-generated-initial-map
  ask patches [ set biomass 0 ]
  let remaining initial-biomass-level
  while [remaining > 0] [
    let eligible patches with [biomass < 3]
    if not any? eligible [ stop ]
    ask one-of eligible [ set biomass biomass + 1 ]
    set remaining remaining - 1
  ]
end

to setup-households
  create-households household-count [
    set shape "person"
    set size 0.2
    set color 15 + who * 10
    setxy (min-pxcor - 0.5) (max-pycor - who * 0.25)
    set hid who + 1
    set strategy assign-household-strategy
    set harvest-total 0
    set harvest-last-round 0
    set label (word "H" hid ":" strategy)
  ]
end

to reset-metrics
  set round-number 0
  set cumulative-harvest 0
  set cumulative-newborns 0
  set total-biomass sum [biomass] of patches
  set trajectory-data []
  set current-protected-ids []
  record-trajectory-row
end

to go
  set round-number round-number + 1
  clear-round-state
  allocate-nests
  choose-protected-areas
  place-harvesters
  resolve-harvest
  compute-bird-reproduction
  update-unoccupied-biomass
  update-history
  update-metrics
  recolor-patches
  update-patch-labels
  record-trajectory-row

  show "avant ask households"
  show count households
  ask households [
   show  harvest-total
  ]

  tick
end

to go-until-end
  while [round-number < max-rounds] [
    go
  ]
end

to clear-round-state
  ask patches [
    set protected? false
    set nesting? false
    set previous-newborns newborns-last-round
    set newborns-last-round 0
    set harvested-this-round? false
    set scheduled-households []
  ]
  ask households [
    set harvest-last-round 0
  ]
end

to allocate-nests
  ask patches [
    set nesting? (biomass >= 2)
  ]
end

to choose-protected-areas
  set current-protected-ids []
  if round-number = 1 [ stop ]
  if ranger-strategy = "no-action" [ stop ]

  if ranger-strategy = "crusader" [
    set current-protected-ids top-biomass-cell-ids (patches with [biomass >= 2]) protected-area-limit
  ]

  if ranger-strategy = "negotiator" [
    let chosen top-biomass-cell-ids (patches with [biomass = 2]) protected-area-limit
    if length chosen < protected-area-limit [
      let missing protected-area-limit - length chosen
      let extra top-biomass-cell-ids (patches with [biomass >= 2 and not member? cell-id chosen]) missing
      set chosen sentence chosen extra
    ]
    set current-protected-ids chosen
  ]

  if ranger-strategy = "naturalist" [
    set current-protected-ids top-naturalist-cell-ids protected-area-limit
  ]

  if ranger-strategy = "manager" [
    set current-protected-ids manager-cluster protected-area-limit
  ]

  ask patches with [member? cell-id current-protected-ids] [
    set protected? true
  ]
end

to place-harvesters
  ask patches [
    set scheduled-households []
  ]

  ask households [
    repeat harvesters-per-household [
      let target choose-target-patch self
      ask target [
        set scheduled-households lput ([who] of myself) scheduled-households
      ]
    ]
  ]
end

to-report choose-target-patch [hh]
  let s [strategy] of hh

  if s = "maximizer" [
    report max-one-of patches [biomass]
  ]

  if s = "lone-rider" [
    if any? patches with [biomass <= 1] [
      report one-of patches with [biomass <= 1]
    ]
    report min-one-of patches [biomass]
  ]

  if s = "explorer" [
    report one-of patches
  ]

  if s = "poacher" [
    if any? patches with [protected?] [
      report max-one-of patches with [protected?] [biomass]
    ]
    report max-one-of patches [biomass]
  ]

  if s = "fixed-plan" [
    report max-one-of patches [biomass]
  ]

  if s = "sobriety" [
    if any? patches with [biomass = 1] [
      report one-of patches with [biomass = 1]
    ]
    report min-one-of patches [biomass]
  ]

  report one-of patches
end

to resolve-harvest
  ask patches with [length scheduled-households > 0] [
    set harvested-this-round? true

    let queue shuffle scheduled-households
    let n length queue
    let available biomass

    if n = 1 [
      let winner-id first queue
      let gain min (list 2 available)

      ask turtle winner-id [
        set harvest-total harvest-total + gain
        set harvest-last-round harvest-last-round + gain
      ]

      set biomass max (list 0 (biomass - gain))
    ]

    if n > 1 [
      if available = 1 [
        let winner-id first queue
        ask turtle winner-id [
          set harvest-total harvest-total + 1
          set harvest-last-round harvest-last-round + 1
        ]
        set biomass 0
      ]

      if available = 2 [
        let winner-id first queue
        ask turtle winner-id [
          set harvest-total harvest-total + 2
          set harvest-last-round harvest-last-round + 2
        ]
        set biomass 0
      ]

      if available = 3 [
        let winner1 first queue
        let winner2 item 1 queue

        ask turtle winner1 [
          set harvest-total harvest-total + 2
          set harvest-last-round harvest-last-round + 2
        ]
        ask turtle winner2 [
          set harvest-total harvest-total + 1
          set harvest-last-round harvest-last-round + 1
        ]
        set biomass 0
      ]
    ]
  ]
end

to compute-bird-reproduction
  ask patches with [nesting?] [
    if length scheduled-households > 0 [
      set newborns-last-round 0
    ]
    if length scheduled-households = 0 [
      let unoccupied-neighbors count neighbors with [length scheduled-households = 0]
      let total-neighbors count neighbors

      if total-neighbors = 8 [
        if unoccupied-neighbors >= 7 [ set newborns-last-round 2 ]
        if unoccupied-neighbors >= 5 and unoccupied-neighbors <= 6 [ set newborns-last-round 1 ]
        if unoccupied-neighbors < 5 [ set newborns-last-round 0 ]
      ]

      if total-neighbors = 5 [
        if unoccupied-neighbors >= 4 [ set newborns-last-round 2 ]
        if unoccupied-neighbors = 3 [ set newborns-last-round 1 ]
        if unoccupied-neighbors < 3 [ set newborns-last-round 0 ]
      ]

      if total-neighbors = 3 [
        if unoccupied-neighbors = 3 [ set newborns-last-round 2 ]
        if unoccupied-neighbors = 2 [ set newborns-last-round 1 ]
        if unoccupied-neighbors < 2 [ set newborns-last-round 0 ]
      ]
    ]
  ]
end

to update-unoccupied-biomass
  ask patches with [not harvested-this-round?] [
    if harvested-last-round? [
      set biomass min (list 3 (biomass + 1))
    ]
    if not harvested-last-round? and not harvested-two-rounds-ago? [
      set biomass max (list 0 (biomass - 1))
    ]
  ]
end

to update-history
  ask patches [
    set harvested-two-rounds-ago? harvested-last-round?
    set harvested-last-round? harvested-this-round?
  ]
end

to update-metrics
  set total-biomass sum [biomass] of patches
  set cumulative-harvest cumulative-harvest + sum [harvest-last-round] of households
  set cumulative-newborns cumulative-newborns + sum [newborns-last-round] of patches
end

to recolor-patches
  ask patches [
    recolor-one-patch
  ]
end

to recolor-one-patch
  if biomass = 0 [ set pcolor white ]
  if biomass = 1 [ set pcolor 53 ]
  if biomass = 2 [ set pcolor 63 ]
  if biomass = 3 [ set pcolor 67 ]

  if newborns-last-round = 1 [ set pcolor sky ]
  if newborns-last-round = 2 [ set pcolor violet ]

  if protected? [ set pcolor yellow ]
  if harvested-this-round? [ set pcolor red + 2 ]
  if protected? and harvested-this-round? [ set pcolor orange ]
end

to update-patch-labels
  ask patches [
    set plabel (word biomass " | H" length scheduled-households " | B" newborns-last-round)
    set plabel-color black
  ]
end

to record-trajectory-row
  let row (list
    round-number
    total-biomass
    cumulative-harvest
    cumulative-newborns
    count patches with [protected?]
    count patches with [nesting?]
    count patches with [harvested-this-round?]
    communication?
    household-strategy-mode
    ranger-strategy
    household-count
    harvesters-per-household
    protected-area-compliance
    coordination-strength
    poacher-share
  )
  set trajectory-data lput row trajectory-data
end

to export-current-trajectory [file-name]
  let rows sentence
    (list ["round" "total_biomass" "cumulative_harvest" "cumulative_newborns" "protected_cells" "nesting_cells" "harvested_cells" "communication" "household_strategy_mode" "ranger_strategy" "household_count" "harvesters_per_household" "protected_area_compliance" "coordination_strength" "poacher_share"])
    trajectory-data
  csv:to-file file-name rows
end

to run-monte-carlo [repetitions file-prefix]
  let all-rows (list ["run" "round" "total_biomass" "cumulative_harvest" "cumulative_newborns" "protected_cells" "nesting_cells" "harvested_cells" "communication" "household_strategy_mode" "ranger_strategy" "household_count" "harvesters_per_household" "protected_area_compliance" "coordination_strength" "poacher_share"])

  let run-id 1
  while [run-id <= repetitions] [
    random-seed fresh-seed
    setup
    go-until-end
    foreach trajectory-data [
      row ->
      set all-rows lput (fput run-id row) all-rows
    ]
    set run-id run-id + 1
  ]

  csv:to-file (word file-prefix ".csv") all-rows
end

to-report assign-household-strategy
  if household-strategy-mode != "mixed" [ report household-strategy-mode ]

  let draw random-float 1.0
  if draw < poacher-share [ report "poacher" ]
  if draw < poacher-share + 0.38 [ report "maximizer" ]
  if draw < poacher-share + 0.38 + 0.32 [ report "lone-rider" ]
  if draw < poacher-share + 0.38 + 0.32 + 0.29 [ report "explorer" ]
  report "fixed-plan"
end

to-report round-harvest
  report sum [harvest-last-round] of households
end

to-report round-births
  report sum [newborns-last-round] of patches
end

to-report summary
  report (list
    (word "round=" round-number)
    (word "biomass=" total-biomass)
    (word "harvest=" cumulative-harvest)
    (word "newborns=" cumulative-newborns)
  )
end

to-report top-biomass-cell-ids [candidate-patches limit-cells]
  let chosen []
  let remaining candidate-patches

  while [length chosen < limit-cells and any? remaining] [
    let p max-one-of remaining [biomass]
    set chosen lput [cell-id] of p chosen
    set remaining remaining with [self != p]
  ]

  report chosen
end

to-report top-naturalist-cell-ids [limit-cells]
  let chosen []
  let remaining patches with [biomass >= 2]

  while [length chosen < limit-cells and any? remaining] [
    let p max-one-of remaining [(previous-newborns * 10) + biomass]
    set chosen lput [cell-id] of p chosen
    set remaining remaining with [self != p]
  ]

  report chosen
end

to-report manager-cluster [limit-cells]
  let suitable patches with [biomass >= 2]
  if not any? suitable [ report [] ]

  let seed max-one-of suitable [
    (biomass * 10) + count neighbors with [biomass >= 2]
  ]

  let chosen (list [cell-id] of seed)

  while [length chosen < limit-cells] [
    let frontier no-patches

    foreach chosen [
      cid ->
      set frontier (patch-set frontier ([neighbors] of (patch-from-id cid)))
    ]

    let candidates frontier with [biomass >= 2 and not member? cell-id chosen]
    if not any? candidates [ report chosen ]

    let next-patch max-one-of candidates [
      (biomass * 10) + count neighbors with [biomass >= 2]
    ]

    set chosen lput [cell-id] of next-patch chosen
  ]

  report chosen
end

to-report fresh-seed
  report 100000 + random 900000
end

to-report patch-from-id [cid]
  let row floor ((cid - 1) / 5)
  let col ((cid - 1) mod 5)
  report patch col (3 - row)
end

to-report patch-id [x y]
  let row (3 - y)
  report row * 5 + x + 1
end
@#$#@#$#@
GRAPHICS-WINDOW
204
10
436
198
-1
-1
45.0
1
10
1
1
1
0
1
1
1
0
4
0
3
0
0
1
ticks
30.0

BUTTON
33
25
100
58
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
120
84
183
117
NIL
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
454
10
654
160
total-biomass
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot total-biomass"

PLOT
453
164
653
314
cumulative-harvest
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot cumulative-harvest"

PLOT
454
317
654
467
cumulative-newborns
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot cumulative-newborns"

PLOT
237
222
437
372
round-harvest
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot round-harvest"

CHOOSER
32
148
198
193
household-strategy-mode
household-strategy-mode
"mixed" "maximizer" "lone-rider" "explorer" "poacher" "fixed-plan"
4

SLIDER
27
201
199
234
household-count
household-count
0
5
5.0
1
1
NIL
HORIZONTAL

SLIDER
25
237
245
270
harvesters-per-household
harvesters-per-household
0
4
4.0
1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.3.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
