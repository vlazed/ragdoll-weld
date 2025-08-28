# Ragdoll Weld <!-- omit from toc -->

Constrain entities without unfreezing

## Table of Contents <!-- omit from toc -->

- [Description](#description)
  - [Features](#features)
  - [Rational](#rational)
- [Disclaimer](#disclaimer)
- [Pull Requests](#pull-requests)

## Description

This adds a welding tool which does not require an entity to be unfreezed, allowing ragdoll poses to be preserved.

### Features

- **Weld Graph**: View all welds and modify them in a convenient graph
- **(TODO) GMod save or duplicator support**: Ragdoll welds will persist between saves and dupes.
- **(TODO) Bone constraints**: Ragdoll welds can either follow a physical bone or a nonphysical bone.

### Rational

There are different tools to make one entity follow another. I categorize them as the following:

- Constrain-based: These tools use the physics system to make an entity follow another. One simple example is the weld tool
- Parent-based: These tools simply call `:SetParent` on an entity. Bonemerging tools are use this function, with the `EF_BONEMERGE` enum. These entities exist outside of the world and cannot be selected. Examples include the Multi-Parent tool and the Advanced Bonemerger.

Ragdoll Mover can manipulate entities constrained by the above tools. It contains a constrained entity lock mechanism, which allows one entity to follow another entity if the gizmos are being moved. This tool also allows one to manipulate the bonemerged entities.

For posing, all three categories may be used to the user's preference. For animation, I found that I favor one category over another depending on the use case. Despite this, each category has its own flaws:

- Constrain-based tools introduce a noticeable delay when an object is following another entity. This is not desirable when recording with video playback. A workaround is to record position keyframes; however, if multiple objects are involved, this can be tedious to accomplish, and it may increase the animation file size. In addition, constraints are limited to physics bones, which may produce offsets during inbetweening
- Parented entities are not easily manipulable without another tool, such as Ragdoll Mover. Parented entities, especially bonemerged ones, may also suffer from gimbal lock. Finally, they cannot be controlled by the physics system.

While Ragdoll Mover allows the user to avoid these pitfalls, it can only be avoided if the tool is used. Without the helper of external scripts, Stop Motion Helper cannot control the positioning of constrained entities.

This is where this tool comes in: it is an active version of Ragdoll Mover's constrained entity locking system with the benefits of parented entities (no gimbal lock) and the benefits of constrain-based tools.

## Disclaimer

**This tool has been tested in singleplayer.** Although this tool may function in multiplayer, please expect bugs and report any that you observe in the issue tracker.

## Pull Requests

When making a pull request, make sure to confine to the style seen throughout. Try to add types for new functions or data structures. I used the default [StyLua](https://github.com/JohnnyMorganz/StyLua) formatting style.
