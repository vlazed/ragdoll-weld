local helpers = {}

-- Cache the sorted indices so we don't iterate two more times than necessary
local sortedIndicesDictionary = {}

---Helper function to iterate over an array with nonconsecutive integers ("holes" in the middle of the array, or zero or negative indices)
---@source https://subscription.packtpub.com/book/game-development/9781849515504/1/ch01lvl1sec14/extending-ipairs-for-use-in-sparse-arrays
---@generic T
---@param t T[] Table to iterate over
---@param identifier string A unique key to store the table's sorted indices
---@param changed boolean? Has the table's state in some way?
---@return fun(): integer, T
function helpers.ipairs_sparse(t, identifier, changed)
	-- tmpIndex will hold sorted indices, otherwise
	-- this iterator would be no different from pairs iterator
	local tmpIndex = {}

	if changed or not sortedIndicesDictionary[identifier] then
		local index, _ = next(t)
		while index do
			tmpIndex[#tmpIndex + 1] = index
			index, _ = next(t, index)
		end

		-- sort table indices
		table.sort(tmpIndex)

		sortedIndicesDictionary[identifier] = tmpIndex
	else
		tmpIndex = sortedIndicesDictionary[identifier]
	end
	local j = 1
	-- get index value
	return function()
		local i = tmpIndex[j]
		j = j + 1
		if i then
			return i, t[i]
		end
	end
end

---@param ent Entity Entity to translate physics bone
---@param physBone integer Physics object id
---@return integer bone Translated bone id
local function physBoneToBone(ent, physBone)
	return ent:TranslatePhysBoneToBone(physBone)
end
helpers.physBoneToBone = physBoneToBone

---@type {[string]: {[integer]: integer}}
local boneToPhysMap = {}

---@source https://github.com/Winded/RagdollMover/blob/a761e5618e9cba3440ad88d44ee1e89252d72826/lua/autorun/ragdollmover.lua#L201
---@param ent Entity Entity to translate bone
---@param bone integer Bone id
---@return integer physBone Physics object id
local function boneToPhysBone(ent, bone)
	local model = ent:GetModel()
	if boneToPhysMap[model] and boneToPhysMap[model][bone] then
		return boneToPhysMap[model][bone]
	else
		boneToPhysMap[model] = boneToPhysMap[model] or {}
		for i = 0, ent:GetPhysicsObjectCount() - 1 do
			local b = ent:TranslatePhysBoneToBone(i)
			if bone == b then
				boneToPhysMap[model][b] = i
				return i
			end
		end
	end

	return -1
end
helpers.boneToPhysBone = boneToPhysBone

do
	---@alias PhysBoneParents table<integer, integer>
	---@type table<string, PhysBoneParents> Mapping of physobjs indices to their parent's, for faster lookup
	local physBoneParents = {}

	---@source https://github.com/Winded/RagdollMover/blob/a761e5618e9cba3440ad88d44ee1e89252d72826/lua/autorun/ragdollmover.lua#L209
	---@param entity Entity Entity to obtain bone information
	---@param physBone integer Physics object id
	---@return integer parent Physics object parent of physBone
	function helpers.getPhysBoneParent(entity, physBone)
		local model = entity:GetModel()
		if physBoneParents[model] and physBoneParents[model][physBone] then
			return physBoneParents[model][physBone]
		end
		physBoneParents[model] = physBoneParents[model] or {}

		local b = physBoneToBone(entity, physBone)
		local i = 1
		while true do
			b = entity:GetBoneParent(b)
			local parent = boneToPhysBone(entity, b)
			if parent >= 0 and parent ~= physBone then
				physBoneParents[model][physBone] = parent
				return parent
			end
			i = i + 1
			if i > 256 then --We've gone through all possible bones, so we get out.
				break
			end
		end
		physBoneParents[model][physBone] = -1
		return -1
	end
end

---@param entity Entity
---@return string
function helpers.getEntityName(entity)
	local modelOnly = string.GetFileFromFilename(entity:GetModel())

	return Format("%s [%d]", modelOnly, entity:EntIndex())
end

return helpers
