# draw-visualizer
> ⚠️  **THIS PROJECT IS A WIP AND VERY UNSTABLE!** ⚠️

Roblox plugin heavily inspired by the [osu!framework draw visualizer](https://github.com/ppy/osu-framework/wiki/Debug-Overlays:-Draw-Visualizer). This is a plugin that aims to enable speedy traversal of your UI hierarchy and modification of properties without having to use the default Explorer and Properties windows.

## recent demo (very buggy):
https://user-images.githubusercontent.com/64768843/191028033-9112289f-b8bc-4541-9a8b-a713ff0dc80d.mp4

UI is written in [Blend](https://quenty.github.io/NevermoreEngine/api/Blend) (included in Quenty's [NevermoreEngine](https://github.com/Quenty/NevermoreEngine))

## todo:
### current tasks:
- [~] open properties window??
- [ ] right click instance to ignore it in target selection
- [ ] sort instances based on layoutorder
- [ ] don't re-render the whole tree when we move up a parent
- [ ] hide instances that aren't on-screen
- [ ] hide instances that are under a collapsed instance group
- [ ] figure out what the max depth size can reasonably be after more optimizations

#### custom input fields:
- [ ] text input (string, number)
- [ ] checkbox (boolean)
- [ ] type input (udim, udim2, vector2, vector3, rect)
- [ ] color selection (brickcolor, color3)
- [ ] dropdown (font, enum)
