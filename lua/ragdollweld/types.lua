---@meta

---@generic T, U
---@alias Set<T, U> {[T]: U}

---@alias EntitySet Set<Entity, boolean>

---@class OffsetData Offset of a physics bone with respect to its parent bone
---@field pos Vector?
---@field ang Angle?
---@field parent PhysObj?

---@class ArcData
---@field entity Entity
---@field outgoing Entity
---@field incoming EntitySet All the entities connected to this entity
---@field pos Vector
---@field ang Angle
---@field phys boolean Whether the outgoing arc's bone id will be used to weld to a physics bone
---@field id integer The bone id of the outgoing arc entity to constrain to
---@field updating boolean Whether to update the offsets immediately when the outgoing arc moves
---@field offsetData OffsetData[]

---@class EntityExplorer: DPanel
---@field graph ragdollweld_graph
---@field list DListView
---@field search DTextEntry

---@class EntityData: DForm
---@field data ArcData
---@field label DLabel
---@field pos DTextEntry
---@field ang DTextEntry
---@field phys DCheckBox
---@field id DNumberWang
---@field update DButton
---@field updating DCheckBox

---@class EntityGraph: DPanel

---@class EntityNode: DPanelOverlay
---@field name DPanel
---@field entity Entity

---@class PanelState
---@field entities ArcData[]

---@class PanelChildren
---@field explorer EntityExplorer A graph view of all ragdoll welds, with a list and search bar on the right
---@field data EntityData When a node on the graph, a list, or ragdoll is right-clicked

---@class PanelProps
