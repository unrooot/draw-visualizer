# draw-visualizer
> ⚠️  **THIS PROJECT IS A WIP! EXPECT BUGS!** ⚠️

Roblox UI debugging plugin inspired by the [osu!framework draw visualizer](https://github.com/ppy/osu-framework/wiki/Debug-Overlays:-Draw-Visualizer). This is a plugin that aims to enable speedy traversal of your UI hierarchy and modification of properties without having to use the default Explorer and Properties windows.

## recent demo (less buggy!):
https://github.com/unrooot/draw-visualizer/assets/64768843/a9634979-14bf-41e8-b817-a75d1f4cd91b


UI is written in [Blend](https://quenty.github.io/NevermoreEngine/api/Blend) (included in Quenty's [NevermoreEngine](https://github.com/Quenty/NevermoreEngine))

## todo:
### current tasks:
- [x] when you move up a parent, the entire tree is re-constructed
- [x] open properties window
- [x] copy command palette ui into properties
- [x] more visible highlights + highlighting on the selected group in the hierarchy view
- [x] space to toggle highlighted group
- [x] improve selection UX (tab/shift+tab)
- [x] when looking at the absolutesize of a guiobject in the hierarchy, the number is currently rounded up or down - when you hover over it it should show the accurate/non-rounded number
- [x] GuiObjects that are Visible false need a specific visual state
- [x] fix flashing hovered instances in the hierarchy
- [ ] if a group has a UIListLayout/UIGridLayout in it, the subsequent entries/groups should be sorted using the same SortOrder & LayoutOrder
- [ ] in play solo the selection position is inaccurate (topbar)
- [ ] modes to visualize global ui states
  - [ ] all visible GuiButtons
  - [ ] AutoLocalize preview mode
- [ ] hierarchy view needs to be virtualized
- [ ] need to handle new/removed instances in the list
- [ ] design & program properties ui
- [ ] polish command palette
- [ ] add functionality to command palette
  - [ ] custom input fields
  - [ ] property editing

#### custom input fields:
- [ ] text input (string, number)
- [ ] checkbox (boolean)
- [ ] type input (udim, udim2, vector2, vector3, rect)
- [ ] color selection (brickcolor, color3)
- [ ] dropdown (font, enum)
