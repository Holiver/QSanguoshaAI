function hasExplicitRebel(room)
	for _, player in sgs.qlist(room:getAllPlayers()) do
		if sgs.isRolePredictable() and  sgs.evaluatePlayerRole(player) == "rebel" then return true end
		if sgs.compareRoleEvaluation(player, "rebel", "loyalist") == "rebel" then return true end
	end
	return false
end

function sgs.isGoodHp(player)
	local goodHp = player:getHp() > 1 or getCardsNum("Peach", player) >= 1 or getCardsNum("Analeptic", player) >= 1
					or (player:hasSkill("buqu") and player:getPile("buqu"):length() <= 4)
					or (player:hasSkill("niepan") and player:getMark("@nirvana") > 0)
					or (player:hasSkill("fuli") and player:getMark("@laoji") > 0)
	if goodHp then 
		return goodHp 
	else
		for _, p in sgs.qlist(global_room:getOtherPlayers(player)) do
			if sgs.compareRoleEvaluation(p,"rebel","loyalist")==sgs.compareRoleEvaluation(player,"rebel","loyalist") 
					and getCardsNum("Peach",p)>0 and not global_room:getCurrent():hasSkill("wansha") then
				return true
			end
		end		
		return false
	end
end

function sgs.isGoodTarget(player,targets, self)
	local arr = {"jieming","yiji","guixin","fangzhu","neoganglie","nosmiji","xuehen","xueji"}
	local m_skill=false
	local attacker = global_room:getCurrent()

	if attacker:hasSkill("jueqing") then return true end
	
	if targets and type(targets)=="table" then 
		if #targets==1 then return true end
		local foundtarget=false
		for i = 1, #targets, 1 do
			--if sgs.isGoodTarget(targets[i]) and not (self:cantbeHurt(targets[i]) or self:slashProhibit(nil,target[i])) then
			if sgs.isGoodTarget(targets[i]) and not self:cantbeHurt(targets[i]) then
				foundtarget = true
				break
			end
		end
		if not foundtarget then return true end
	end

	for _, masochism in ipairs(arr) do
		if player:hasSkill(masochism) then
			if masochism=="nosmiji" and player:isWounded() then 
				m_skill =false
			else
				m_skill=true
				break
			end
		end
	end
		
	if player:hasSkill("huilei") and player:getHp()==1 then
		if attacker:getHandcardNum()>=4 then return false end
		return sgs.compareRoleEvaluation(player, "rebel", "loyalist") == "rebel"
	end
	
	if player:hasSkill("wuhun") and (attacker:isLord() or player:getHp()<=2) then 
		return false
	end

	if player:hasLordSkill("shichou") and player:getMark("@hate")==0 then
		if player:getTag("ShichouTarget") and player:getTag("ShichouTarget"):toPlayer() and player:getTag("ShichouTarget"):toPlayer():isAlive() then
			return false
		end
	end

	if player:hasSkill("hunzi") and player:getMark("hunzi") == 0 and player:isLord() and player:getHp() == 2 and sgs.current_mode_players["loyalist"] > 0 then
		return false
	end
	
	if m_skill and sgs.isGoodHp(player) then
		return false
	else
		return true
	end 	
end

function SmartAI:canAttack(enemy, attacker, nature)
	attacker = attacker or self.player
	nature = nature or sgs.DamageStruct_Normal
	if #self.enemies == 1 or self:hasSkills("jueqing") then return true end
	if self:getDamagedEffects(enemy, attacker) or (enemy:getHp() > getBestHp(enemy) and #self.enemies > 1) or not sgs.isGoodTarget(enemy, self.enemies, self) then return false end
	if self:objectiveLevel(enemy) <= 3 or self:cantbeHurt(enemy) or not self:damageIsEffective(enemy, nature , attacker) then return false end
	if nature ~= sgs.DamageStruct_Normal and enemy:isChained() and not self:isGoodChainTarget(enemy) then return false end
	return true
end

function sgs.getDefenseSlash(player)	
	local attacker = global_room:getCurrent()
	local defense = getCardsNum("Jink",player)

	local knownJink = getKnownCard(player,"Jink",true)

	if sgs.card_lack[player:objectName()]["Jink"] == 1 and knownJink ==0 then defense =0 end
	
	defense= defense + knownJink * 1.2
	
	local hasEightDiagram=false
	
	if (player:hasArmorEffect("EightDiagram") or (player:hasSkill("bazhen") and not player:getArmor())) 
	  and not IgnoreArmor(attacker, player) then
		hasEightDiagram=true
	end
	
	if hasEightDiagram then 
		defense = defense + 1.3 
		if player:hasSkill("tiandu") then defense = defense + 0.6 end
	end

	if player:hasSkill("tuntian") and getCardsNum("Jink",player) >= 1 then
		defense = defense + 1.5	
	end
	
	local hujiaJink=0
	if player:hasLordSkill("hujia") then
			local lieges = global_room:getLieges("wei", player)			
			for _, liege in sgs.qlist(lieges) do
				if sgs.compareRoleEvaluation(liege,"rebel","loyalist") == sgs.compareRoleEvaluation(player,"rebel","loyalist") then
					hujiaJink = hujiaJink + getCardsNum("Jink",liege)
					if liege:hasArmorEffect("EightDiagram") then hujiaJink = hujiaJink + 0.8 end
				end
			end
			defense = defense + hujiaJink
	end

	if player:getMark("@tied") > 0 then defense = defense + 1 end

	local hcard = player:getHandcardNum()
	if attacker:hasSkill("liegong") and attacker:canSlashWithoutCrossbow() and (hcard >= attacker:getHp() or hcard <= attacker:getAttackRange()) then
		defense = 0
	end

	if player:hasFlag("QianxiTarget") then
		local red = player:getMark("@qianxi_red") > 0
		local black = player:getMark("@qianxi_black") > 0
		if red then
			if player:hasSkill("qingguo") or (player:hasSkill("longhun") and player:isWounded()) then
				defense = defense - 1
			else
				defense = 0
			end
		elseif black then
			if player:hasSkill("qingguo") then
				defense = defense - 1
			end
		end
	end
	
	local m = sgs.masochism_skill:split("|")
	for _, masochism in ipairs(m) do
		if player:hasSkill(masochism) and sgs.isGoodHp(player) and not attacker:hasSkill("jueqing") then
			defense = defense + 1.3
		end
	end

	if not sgs.isGoodTarget(player) then defense = defense + 10 end

	if player:hasSkill("rende") and player:getHp() > 2 then defense = defense + 3 end
	if player:hasSkill("kuanggu") and player:getHp() > 1 then defense = defense + 0.2 end
	if player:hasSkill("zaiqi") and player:getHp() > 1 then defense = defense + 0.35 end
	
	if player:getHp() > getBestHp(player) then defense = defense + 1.3 end

	if player:getHp() <= 2 then defense = defense - 0.4 end
	
	local playernum=global_room:alivePlayerCount()
	if (player:getSeat()-attacker:getSeat()) % playernum >= playernum-2 and playernum>3 and player:getHandcardNum()<=2 and player:getHp()<=2 then
		defense = defense - 0.4
	end

	if player:hasSkill("tianxiang") then defense = defense + player:getHandcardNum() * 0.5 end

	if player:getHandcardNum() == 0 and hujiaJink == 0 and not player:hasSkill("kongcheng") then
		if player:getHp() <= 1 then defense = defense - 2.5 end
		if player:getHp() == 2 then defense = defense - 1.5 end
		if not hasEightDiagram then defense = defense - 2 end
		if attacker:hasWeapon("GudingBlade") and player:getHandcardNum() == 0 
		  and not (player:hasArmorEffect("SilverLion") and not IgnoreArmor(attacker, player)) then
			defense = defense - 2
		end
	end

	local has_fire_slash
	local cards = sgs.QList2Table(attacker:getHandcards())
	for i = 1, #cards, 1 do		
		if (attacker:hasWeapon("Fan") and cards[i]:isKindOf("Slash") and not cards[i]:isKindOf("ThunderSlash")) or cards[i]:isKindOf("FireSlash")  then
			has_fire_slash = true
			break
		end
	end
	
	if player:hasArmorEffect("Vine") and not IgnoreArmor(attacker, player) and has_fire_slash then 
		defense = defense - 0.6
	end	

	if isLord(player) then 
		defense = defense -0.4
		if sgs.isLordInDanger() then defense = defense - 0.7 end
	end

	if (sgs.ai_chaofeng[player:getGeneralName()] or 0)>=3 then
		defense = defense - math.max(6, (sgs.ai_chaofeng[player:getGeneralName()] or 0)) * 0.035
	end

	if not player:faceUp() then defense = defense -0.35 end

	if player:containsTrick("indulgence") and not player:containsTrick("YanxiaoCard") then defense = defense - 0.15  end
	if player:containsTrick("supply_shortage") and not player:containsTrick("YanxiaoCard") then defense = defense - 0.15  end

	if (attacker:hasSkill("roulin") and player:isFemale()) or (attacker:isFemale() and player:hasSkill("roulin")) then
		defense = defense - 2.4
	end

	
	if not hasEightDiagram then
		if player:hasSkill("jijiu") then defense = defense - 3 end
		if player:hasSkill("jieyin") then defense = defense - 2.5 end
	end
	return defense
end

sgs.ai_compare_funcs["defenseSlash"] = function(a,b)
	return sgs.getDefenseSlash(a) < sgs.getDefenseSlash(b)
end

function SmartAI:slashProhibit(card,enemy)
	local mode = self.room:getMode()
	if mode:find("_mini_36") then return self.player:hasSkill("keji") end
	card = card or sgs.Sanguosha:cloneCard("slash", sgs.Card_NoSuit, 0)
	for _, askill in sgs.qlist(enemy:getVisibleSkillList()) do
		local filter = sgs.ai_slash_prohibit[askill:objectName()]
		if filter and type(filter) == "function" and filter(self, enemy, card) then return true end
	end

	if self:isFriend(enemy) then
		if card:isKindOf("FireSlash") or self.player:hasWeapon("Fan") or self.player:hasSkill("zonghuo") then
			if self:isEquip("Vine", enemy) and not (enemy:isChained() and self:isGoodChainTarget(enemy)) then return true end
		end
		if enemy:isChained() and (card:isKindOf("NatureSlash") or self.player:hasSkill("zonghuo")) and (not self:isGoodChainTarget(enemy) and not self.player:hasSkill("jueqing")) and
			self:slashIsEffective(card,enemy) then return true end
		if getCardsNum("Jink",enemy) == 0 and enemy:getHp() < 2 and self:slashIsEffective(card,enemy) then return true end
		if enemy:isLord() and self:isWeak(enemy) and self:slashIsEffective(card,enemy) then return true end
		if self:isEquip("GudingBlade") and enemy:isKongcheng() then return true end
	else
		if enemy:isChained() and not self:isGoodChainTarget(enemy) and not self.player:hasSkill("jueqing") and self:slashIsEffective(card,enemy) 
			and (card:isKindOf("NatureSlash") or self.player:hasSkill("zonghuo")) then
			return true
		end
	end

	return self.room:isProhibited(self.player, enemy, card) or not self:slashIsEffective(card, enemy) 
end

function SmartAI:canLiuli(other, another)
	if not other:hasSkill("liuli") then return false end
	local n = other:getHandcardNum()
	if n > 0 and (other:distanceTo(another) <= other:getAttackRange()) then return true
	elseif other:getWeapon() and other:getOffensiveHorse() and (other:distanceTo(another) <= other:getAttackRange()) then return true
	elseif other:getWeapon() or other:getOffensiveHorse() then return other:distanceTo(another) <= 1
	else return false end
end

function SmartAI:slashIsEffective(slash, to, ignore_armor)
	if not slash or not to then self.room:writeToConsole(debug.traceback()) return end
	if to:hasSkill("zuixiang") and to:isLocked(slash) then return false end
	if to:hasSkill("yizhong") and not to:getArmor() then
		if slash:isBlack() then
			return false
		end
	end
	if (to:hasSkill("zhichi") and self.room:getTag("Zhichi"):toString() == to:objectName()) then
		return false
	end

	local natures = {
		Slash = sgs.DamageStruct_Normal,
		FireSlash = sgs.DamageStruct_Fire,
		ThunderSlash = sgs.DamageStruct_Thunder,
	}

	local nature = natures[slash:getClassName()]
	if self.player:hasSkill("zonghuo") then nature = sgs.DamageStruct_Fire end
	if not self:damageIsEffective(to, nature) then return false end

	if (to:hasArmorEffect("Vine") or to:getMark("@gale") > 0) and self:getCardId("FireSlash") and slash:isKindOf("ThunderSlash") and self:objectiveLevel(to) >= 3 then
		 return false
	end

	if IgnoreArmor(self.player, to) or ignore_armor then
		return true
	end

	local armor = to:getArmor()
	if armor then
		if armor:objectName() == "RenwangShield" then
			return not slash:isBlack()
		elseif armor:objectName() == "Vine" then
			local skill_name = slash:getSkillName() or ""
			local can_convert = false
			if skill_name == "guhuo" then
				can_convert = true
			else
				local skill = sgs.Sanguosha:getSkill(skill_name)
				if not skill or skill:inherits("FilterSkill") then
					can_convert = true
				end
			end
			return nature ~= sgs.DamageStruct_Normal or (can_convert and (self.player:hasWeapon("Fan") or (self.player:hasSkill("lihuo") and not self:isWeak())))
		end
	end

	return true
end

function SmartAI:slashIsAvailable(player)
	player = player or self.player
	local slash_1 = self:getCard("Slash", player)
	local slash_2 = sgs.Sanguosha:cloneCard("slash", sgs.Card_NoSuit, 0)
	local slash = player:hasSkill("guhuo") and slash_2 or (slash_1 or slash_2)
	assert(slash)
	return slash:isAvailable(player)
end

function SmartAI:shouldUseAnaleptic(target, slash)
	if self:isEquip("SilverLion", target) and not IgnoreArmor(self.player, target) and not self.player:hasSkill("jueqing") then return false end
	if target:hasSkill("zhenlie") then return false end

	if self:hasSkills(sgs.masochism_skill .. "|longhun|buqu|" .. sgs.recover_skill ,target) and 
			self.player:hasSkill("nosqianxi") and self.player:distanceTo(enemy) == 1 then
		return false
	end

	local hcard = target:getHandcardNum()
	if self.player:hasSkill("liegong") and (hcard >= self.player:getHp() or hcard <= self.player:getAttackRange()) then return true end

	if self:isEquip("Axe") and self.player:getCards("he"):length() > 4 then return true end
	if self.player:hasSkill("jie") and slash:isRed() then return true end
	if self.player:hasSkill("tieji") then return true end

	if ((self.player:hasSkill("roulin") and target:isFemale()) or (self.player:isFemale() and target:hasSkill("roulin"))) or self.player:hasSkill("wushuang") then
		if getKnownCard(target, "Jink", true, "he") >= 2 then return false end
		return getCardsNum("Jink", target) < 2
	end
	
	if getKnownCard(target, "Jink", true, "he") >=1 then return false end

	return self:getCardsNum("Analeptic") > 1 or getCardsNum("Jink", target) < 1 or sgs.card_lack[target:objectName()]["Jink"] == 1
end

function SmartAI:useCardSlash(card, use)
	if not self:slashIsAvailable() then return end
	if card:isVirtualCard() and card:subcardsLength() > 0
		and self.player:getWeapon() and self.player:getWeapon():isKindOf("Crossbow")
		and card:getSubcards():contains(self.player:getWeapon():getEffectiveId())
		and not self.player:canSlashWithoutCrossbow() then
		return
	end
	local basicnum = 0
	local cards = self.player:getCards("he")
	cards = sgs.QList2Table(cards)
	for _, acard in ipairs(cards) do
		if acard:getTypeId() == sgs.Card_Basic and not acard:isKindOf("Peach") then basicnum = basicnum + 1 end
	end
	
	local no_distance = sgs.Sanguosha:correctCardTarget(sgs.TargetModSkill_DistanceLimit, self.player, card) > 50 or self.player:hasFlag("slashNoDistanceLimit")
	self.slash_targets = 1 + sgs.Sanguosha:correctCardTarget(sgs.TargetModSkill_ExtraTarget, self.player, card)
	if self.player:hasSkill("duanbing") then self.slash_targets = self.slash_targets + 1 end

	self.predictedRange = self.player:getAttackRange()

	local rangefix = 0
	if card:isVirtualCard() then
		if self.player:getWeapon() and card:getSubcards():contains(self.player:getWeapon():getEffectiveId()) then
			if self.player:getWeapon():getClassName() ~= "Weapon" then
				rangefix = sgs.weapon_range[self.player:getWeapon():getClassName()] - 1
			end
		end
		if self.player:getOffensiveHorse() and card:getSubcards():contains(self.player:getOffensiveHorse():getEffectiveId()) then
			rangefix = rangefix + 1
		end
	end

	if self.player:hasSkill("qingnang") and self:isWeak() and self:getOverflow() == 0 then return end
	local huatuo = self.room:findPlayerBySkillName("jijiu")
	for _, friend in ipairs(self.friends_noself) do
		local slash_prohibit = false
		slash_prohibit = self:slashProhibit(card, friend)
		if (self.player:hasSkill("pojun") and friend:getHp() > 4 and getCardsNum("Jink", friend) == 0 and friend:getHandcardNum() < 3)
		  or self:getDamagedEffects(friend,self.player) 
		  or (friend:hasSkill("leiji") and not self.player:hasFlag("luoyi") and self:hasSuit("spade", true, friend) and (getKnownCard(friend,"Jink",true) >= 1 
		    or (not IgnoreArmor(self.player, friend) and not self:isWeak(friend) and self:isEquip("EightDiagram",friend)))
		  and (hasExplicitRebel(self.room) or not friend:isLord()))
		  or (friend:isLord() and self.player:hasSkill("guagu") and friend:getLostHp() >= 1 and getCardsNum("Jink", friend) == 0)
		  or (friend:hasSkill("jieming") and self.player:hasSkill("rende") and (huatuo and self:isFriend(huatuo)))
		then
			if not slash_prohibit then
				if ((self.player:canSlash(friend, card, not no_distance, rangefix)) or
					(use.isDummy and (self.player:distanceTo(friend, rangefix) <= self.predictedRange))) and
					self:slashIsEffective(card, friend) then
					use.card = card
					if use.to then
						if use.to:length() == self.slash_targets then
							if self.player:hasSkill("duanbing") then
								if self.player:distanceTo(friend, rangefix) == 1 then
									use.to:append(friend)
								end
							else
								use.to:append(friend)
							end
						else
							use.to:append(friend)
						end
						self:speak("hostile", self.player:isFemale())
						if self.slash_targets <= use.to:length() then return end
					end
				end
			end
		end
	end

	local targets = {}
	self:sort(self.enemies, "defenseSlash")
	for _, enemy in ipairs(self.enemies) do
		if not self:slashProhibit(card, enemy) and sgs.isGoodTarget(enemy, self.enemies, self) then 
			table.insert(targets, enemy) 
		end
	end
	
	for _, target in ipairs(targets) do
		local canliuli = false
		for _, friend in ipairs(self.friends_noself) do
			if self:canLiuli(target, friend) and self:slashIsEffective(card, friend) and #targets > 1 and friend:getHp() < 3 then canliuli = true end
		end
		if (self.player:canSlash(target, card, not no_distance, rangefix) or
		(use.isDummy and self.predictedRange and (self.player:distanceTo(target) <= self.predictedRange))) and
		self:objectiveLevel(target) > 3
		and self:slashIsEffective(card, target) and
		not (target:hasSkill("xiangle") and basicnum < 2) and not canliuli and
		not (not self:isWeak(target) and #self.enemies > 1 and #self.friends > 1 and self.player:hasSkill("keji")
			and self:getOverflow() > 0 and not self:isEquip("Crossbow")) then
			-- fill the card use struct
			local usecard = card
			if not use.to or use.to:isEmpty() then
				
				if self:isEquip("Spear") and card:getSkillName() == "Spear" and #self:getCards("Slash") == 0 then 
				elseif self:isEquip("Crossbow", self.player, true) and self:getCardsNum("Slash") > 1 then
				else
					local equips = self:getCards("EquipCard", self.player, "h")
					for _, equip in ipairs(equips) do
						local callback = sgs.ai_slash_weaponfilter[equip:objectName()]
						if callback and type(callback) == "function" and callback(target, self) and
							self.player:distanceTo(target) <= (sgs.weapon_range[equip:getClassName()] or 0) then
							self:useEquipCard(equip, use)
							if use.card then return end
						end
					end
				end
				
				if target:isChained() and self:isGoodChainTarget(target) and not use.card then
					if self:isEquip("Crossbow") and card:isKindOf("NatureSlash") then
						local slashes = self:getCards("Slash")
						for _, slash in ipairs(slashes) do
							if not slash:isKindOf("NatureSlash") and self:slashIsEffective(slash, target)
								and not self:slashProhibit(slash, target) then
								usecard = slash
								break
							end
						end
					elseif not card:isKindOf("NatureSlash") then
						local slash = self:getCard("NatureSlash")
						if slash and self:slashIsEffective(slash, target) and not self:slashProhibit(slash, target) then usecard = slash end
					end
				end
				
				local godsalvation = self:getCard("GodSalvation")
				if godsalvation and godsalvation:getId() ~= card:getId() and self:willUseGodSalvation(godsalvation) and not target:isWounded() then
					use.card = godsalvation return
				end

				local anal = self:searchForAnaleptic(use, target, card)
				if anal and self:shouldUseAnaleptic(target, card) then
					if anal:getEffectiveId() ~= card:getEffectiveId() then use.card = anal return end
				end
			end
			use.card = use.card or usecard
			if use.to and not use.to:contains(target) then 
				if use.to:length() == self.slash_targets then
					if self.player:hasSkill("duanbing") then
						if self.player:distanceTo(target) == 1 then
							use.to:append(target)
						end
					end
				elseif self.slash_targets <= use.to:length() then
					return
				else
					use.to:append(target)
				end
			end
		end 
	end


end

sgs.ai_skill_use.slash = function(self, prompt)
	local parsedPrompt = prompt:split(":")
	local callback = sgs.ai_skill_cardask[parsedPrompt[1]] -- for askForUseSlashTo
	if self.player:hasFlag("slashTargetFixToOne") and type(callback) == "function" then
		local slash
		local target
		for _, player in sgs.qlist(self.room:getOtherPlayers(self.player)) do
			if player:hasFlag("SlashAssignee") then target = player break end
		end
		local target2 = nil
		if #parsedPrompt >= 3 then
			for _, p in sgs.qlist(self.room:getAlivePlayers()) do
				if p:objectName() == parsedPrompt[3] then
					target2 = p
					break
				end
			end
		end
		if not target then return "." end
		local ret
		if parsedPrompt[1] == "collateral-slash" then ret = callback(self, nil, nil, nil, target) else ret = callback(self, nil, nil, target, target2) end
		if ret == nil or ret == "." then return "." end
		slash = sgs.Card_Parse(ret)

		local no_distance = sgs.Sanguosha:correctCardTarget(sgs.TargetModSkill_DistanceLimit, self.player, slash) > 50 or self.player:hasFlag("slashNoDistanceLimit")
		if self.player:canSlash(target, slash, not no_distance) then return ret .. "->" .. target:objectName() end
		return "."
	end
	local slashes = self:getCards("Slash")	
	self:sort(self.enemies, "defenseSlash")
	for _, slash in ipairs(slashes) do
		local no_distance = sgs.Sanguosha:correctCardTarget(sgs.TargetModSkill_DistanceLimit, self.player, slash) > 50 or self.player:hasFlag("slashNoDistanceLimit")
		for _, enemy in ipairs(self.enemies) do
			if self.player:canSlash(enemy, slash, not no_distance) and not self:slashProhibit(slash, enemy)
				and self:slashIsEffective(slash, enemy) and sgs.isGoodTarget(enemy, self.enemies, self)
				and not (self.player:hasFlag("slashTargetFix") and not enemy:hasFlag("SlashAssignee")) then
				return ("%s->%s"):format(slash:toString(), enemy:objectName())
			end
		end
	end
	return "."
end

sgs.ai_skill_use.oldslash = function(self, prompt)
	local slash = self:getCard("Slash")
	if not slash then return "." end
	for _, enemy in ipairs(self.enemies) do
		if self.player:canSlash(enemy, slash, true) and not self:slashProhibit(slash, enemy) 
		and self:slashIsEffective(slash, enemy) and not (self.player:hasFlag("slashTargetFix") and not enemy:hasFlag("SlashAssignee")) then
			return ("%s->%s"):format(slash:toString(), enemy:objectName())
		end
	end
	return "."
end

if sgs.Sanguosha:getVersion() <= "20121221" then sgs.ai_skill_use.slash = sgs.ai_skill_use.oldslash end

sgs.ai_skill_playerchosen.zero_card_as_slash = function(self, targets)
	local slash = sgs.Sanguosha:cloneCard("slash", sgs.Card_NoSuit, 0)
	local targetlist=sgs.QList2Table(targets)
	local arrBestHp, canAvoidSlash = {},{}
	self:sort(targetlist, "defenseSlash")

	for _, target in ipairs(targetlist) do
		if self:isEnemy(target) and not self:slashProhibit(slash ,target) and sgs.isGoodTarget(target, targetlist, self) then
			if self:slashIsEffective(slash,target) then
				if target:getHp() > getBestHp(target) then
					table.insert(arrBestHp,target)
				else
					return target
				end
			else
				table.insert(canAvoidSlash,target)
			end
		end
	end
	for i=#targetlist, 1, -1 do
		local target = targetlist[i]
		if not self:slashProhibit(slash, target) then
			if self:slashIsEffective(slash,target) then
				if self:isFriend(target) and (target:getHp() > getBestHp(target) or self:getDamagedEffects(target,self.player)) then
					return target
				end
			else
				table.insert(canAvoidSlash,target)
			end
		end
	end

	if #canAvoidSlash >0 then return canAvoidSlash[1] end
	if #arrBestHp >0 then return arrBestHp[1] end
	
	self:sort(targetlist, "defenseSlash")
	targetlist = sgs.reverse(targetlist)
	for _, target in ipairs(targetlist) do
		if target:objectName() ~= self.player:objectName() and not self:isFriend(target) then
			return target
		end
	end
	
	return targetlist[1]
end

sgs.ai_card_intention.Slash = function(self, card,from,tos)
	if sgs.ai_liuli_effect then
		sgs.ai_liuli_effect=false
		return
	end
	for _, to in ipairs(tos) do
		local value = 80
		if sgs.ai_collateral then sgs.ai_collateral=false value = 0 end

		if sgs.ai_leiji_effect then
			if from and from:hasSkill("liegong") then return end
			sgs.ai_leiji_effect = false
			if sgs.ai_pojun_effect then
				value = value/1.5
			else
				--value = -value/1.5
				value = 0
			end
		end
		speakTrigger(card,from,to)
		if to:hasSkill("yiji") then
			-- value = value*(2-to:getHp())/1.1
			value = math.max(value*(2-to:getHp())/1.1, 0)
		end
		if from:hasSkill("pojun") and to:getHp() > 3 then value = 0 end
		sgs.updateIntention(from, to, value)
	end
end

sgs.ai_skill_choice.slash_extra_targets = function(self, choices)
	return "no"
end

sgs.ai_skill_cardask["slash-jink"] = function(self, data, pattern, target)
	local effect = data:toSlashEffect()
	local cards = sgs.QList2Table(self.player:getHandcards())
	if (not target or self:isFriend(target)) and effect.slash:hasFlag("nosjiefan-slash") then return "." end
	if sgs.ai_skill_cardask.nullfilter(self, data, pattern, target) then return "." end
	if effect.nature == sgs.DamageStruct_Fire and self.player:hasSkill("ayshuiyong") then return "." end

	if not target then return end
	if self:isFriend(target) then
		if not target:hasSkill("jueqing") then
			if target:hasSkill("rende") and self.player:hasSkill("jieming") then return "." end
			if target:hasSkill("pojun") and not self.player:faceUp() then return "." end
			if (target:hasSkill("jieyin") and (not self.player:isWounded()) and self.player:isMale()) and not self.player:hasSkill("leiji") then return "." end
			if self.player:isChained() and self:isGoodChainTarget(self.player) then return "." end
		end
	else
		if self:hasHeavySlashDamage(target, effect.slash) then return end
		if (self.player:getHandcardNum() == 1 and self:needKongcheng()) or not self:hasLoseHandcardEffective() then return end
		if target:hasSkill("nosqianxi") and target:distanceTo(self.player) == 1 then return end
		if self.player:hasSkill("leiji") then return end
		if target:hasSkill("mengjin") then
			if self:doNotDiscard(self.player, "he", true) then return end
			if self.player:getCards("he"):length() == 1 and not self.player:getArmor() then return end
			if self:hasSkills("jijiu|qingnang") and self.player:getCards("he"):length() > 1 then return "." end
			if self:canUseJieyuanDecrease(target) then return "." end
			if self:willSkipPlayPhase() then return end
			if (self:getCardsNum("Peach") > 0 or self:getCardsNum("Analeptic") > 0) then
				return "."
			end
			if self.player:getHp() > 2 and self.player:getArmor() and not self:needToThrowArmor() then return "." end
			if self.player:getHp() > 2 and self.player:getDefensiveHorse() then return "." end
		end
	
		if self:isEquip("Axe", target) then
			if self:hasSkills(sgs.lose_equip_skill, target) and target:getEquips():length() > 1
			  and target:getCards("he"):length() > 2 then
				return "."
			end
			if target:getHandcardNum() - target:getHp() > 2 then return "." end
		elseif self:isEquip("Blade", target) then
			if self:hasHeavySlashDamage(target, effect.slash, self.player) then
			elseif self:getCardsNum("Jink") <= getCardsNum("Slash", target) or self:hasSkills("jijiu|qingnang") or self:canUseJieyuanDecrease(target) then
				return "."
			end
		end
	end
	if target:hasSkill("dahe") and self.player:hasFlag("dahe") then
		for _, card in ipairs(self:getCards("Jink")) do
			if card:getSuit() == sgs.Card_Heart then
				return card:getId()
			end
		end
		return "."
	end
end

sgs.dynamic_value.damage_card.Slash = true

sgs.ai_use_value.Slash = 4.5
sgs.ai_keep_value.Slash = 2
sgs.ai_use_priority.Slash = 2.6

function SmartAI:useCardPeach(card, use)
	local mustusepeach = false
	if not self.player:isWounded() then return end
	if self.player:hasSkill("longhun") and not self.player:isLord() and
		math.min(self.player:getMaxCards(), self.player:getHandcardNum()) + self.player:getCards("e"):length() > 3 then return end
	local peaches = 0
	local cards = self.player:getHandcards()
	local lord= getLord(self.player)

	cards = sgs.QList2Table(cards)
	for _,card in ipairs(cards) do
		if card:isKindOf("Peach") then peaches = peaches+1 end
	end
	if self.player:isLord() and (self.player:hasSkill("hunzi") and self.player:getMark("hunzi") == 0)
		and self.player:getHp() < 4 and self.player:getHp() > peaches then return end
	for _, enemy in ipairs(self.enemies) do
		if self.player:getHandcardNum() < 3 and 
				(self:hasSkills(sgs.drawpeach_skill,enemy) or getCardsNum("Dismantlement", enemy) >= 1 or
				enemy:hasSkill("jixi") and enemy:getPile("field"):length() >0 and enemy:distanceTo(self.player) == 1 or
				enemy:hasSkill("qixi") and getKnownCard(enemy, "black", nil, "he") >= 1 or
				getCardsNum("Snatch",enemy) >= 1 and enemy:distanceTo(self.player) == 1) then
			mustusepeach = true
		end
	end

	local jinxuandi = self.room:findPlayerBySkillName("wuling")
	if jinxuandi and jinxuandi:getMark("@water") > 0 and self.player:getLostHp() >= 2 then
		mustusepeach = true
	end


	if self.player:hasSkill("rende") and #self.friends_noself>0 then
		return
	end

	if self.player:getHp() == 1 and not (lord and self:isFriend(lord) and lord:getHp() < 2 and self:isWeak(lord)) then
		mustusepeach = true
	end

	if mustusepeach or (self.player:hasSkill("buqu") and self.player:getHp()<1) or peaches > self.player:getHp() then
		use.card = card
		return 
	end
	
	if self:getOverflow() <=0 and #self.friends_noself>0 then
		return
	end
	
	if self.player:hasSkill("kuanggu") and not self.player:hasSkill("jueqing") and self.player:getLostHp()==1 and self.player:getOffensiveHorse() then
		return
	end

	if self.player:getHp() >= getBestHp(self.player) then return end	
	
	if lord and self:isFriend(lord) and lord:getHp() <= 2 and self:isWeak(lord) then 
		if self.player:isLord() then use.card = card end
		if self:getCardsNum("Peach") > 1 and self:getCardsNum("Peach") + self:getCardsNum("Jink") > self.player:getMaxCards() then use.card = card end
		return 
	end	

	self:sort(self.friends, "hp")
	if self.friends[1]:objectName()==self.player:objectName() or self.player:getHp()<2 then
		use.card = card
		return		
	end

	if #self.friends>1 and self.friends[2]:getHp()<3 and not self.friends[2]:hasSkill("buqu") and self:getOverflow() < 1 then
		return
	end

	if self.player:hasSkill("jieyin") and self:getOverflow() > 0 then
		self:sort(self.friends, "hp")
		for _, friend in ipairs(self.friends) do
			if friend:isWounded() and friend:isMale() then return end
		end
	end
		
	if self.player:hasSkill("ganlu") and not self.player:hasUsed("GanluCard") then
		local dummy_use = {isDummy = true}
		self:useSkillCard(sgs.Card_Parse("@GanluCard=."),dummy_use)
		if dummy_use.card then return end
	end

	use.card = card
end

sgs.ai_card_intention.Peach = -120

sgs.ai_use_value.Peach = 6
sgs.ai_keep_value.Peach = 5
sgs.ai_use_priority.Peach = 0.9

sgs.ai_use_value.Jink = 8.9
sgs.ai_keep_value.Jink = 4

sgs.dynamic_value.benefit.Peach = true

sgs.weapon_range.Weapon = 1
sgs.weapon_range.Crossbow = 1
sgs.weapon_range.DoubleSword = 2
sgs.weapon_range.QinggangSword = 2
sgs.weapon_range.IceSword = 2
sgs.weapon_range.GudingBlade = 2
sgs.weapon_range.Axe = 3
sgs.weapon_range.Blade = 3
sgs.weapon_range.Spear = 3
sgs.weapon_range.Halberd = 4
sgs.weapon_range.KylinBow = 5

sgs.ai_skill_invoke.DoubleSword = function(self, data)
	return not self:needKongcheng(self.player, true)
end

function sgs.ai_slash_weaponfilter.DoubleSword(to, self)
	return self.player:getGender()~=to:getGender()
end

function sgs.ai_weapon_value.DoubleSword(self, enemy)
	if enemy and enemy:isMale() ~= self.player:isMale() then return 3 end
end

sgs.ai_skill_cardask["double-sword-card"] = function(self, data, pattern, target)
	if self.player:isKongcheng() then return "." end
	local need_double_jink =target and (target:hasSkill("wushuang") 
			or (target:hasSkill("roulin") and self.player:isFemale()) 
			or (target:isFemale() and self:hasSkills("roulin")))
	if need_double_jink and self:getCardsNum("Jink") == 2 and self.player:getHandcardNum() == 2 then return "." end

	if self:needKongcheng(self.player, true) and self.player:getHandcardNum() <= 2 then
		if self.player:getHandcardNum() == 1 then
			local card = self.player:getHandcards():first()
			return isCard("Jink", card, self.player) and "." or ("$"..card:getEffectiveId())
		end
		if self.player:getHandcardNum() == 2 then
			local first = self.player:getHandcards():first()
			local last = self.player:getHandcards():last()			
			local jink = isCard("Jink", first, self.player) and first or (isCard("Jink", last, self.player) and last)		
			if jink then
				return first:getEffectiveId() == jink:getEffectiveId() and ("$"..last:getEffectiveId()) or ("$"..first:getEffectiveId())
			end
		end		
	end
	if target and self:isFriend(target) then return "." end
	if self:needBear() then return "." end
	if target and self:needKongcheng(target, true) then return "." end
	local cards = self.player:getHandcards()
	for _, card in sgs.qlist(cards) do
		if (card:isKindOf("Slash") and self:getCardsNum("Slash") > 1)
			or (card:isKindOf("Jink") and self:getCardsNum("Jink") > 2)
			or card:isKindOf("Disaster")
			or (card:isKindOf("EquipCard") and not self:hasSkills(sgs.lose_equip_skill))
			or (not self:hasSkills("jizhi") and (card:isKindOf("Collateral") or card:isKindOf("GodSalvation") 
						or card:isKindOf("FireAttack") or card:isKindOf("IronChain") or card:isKindOf("AmazingGrace"))) then
			return "$"..card:getEffectiveId()
		end
	end
	return "."
end

function sgs.ai_weapon_value.QinggangSword(self, enemy)
	if enemy and enemy:getArmor() then return 3 end
end

sgs.ai_skill_invoke.IceSword=function(self, data)
	local damage = data:toDamage()
	local target = damage.to
	if damage.card:hasFlag("drank") then return false end
	if self:isFriend(target) then
		if self:isWeak(target) then return true
		elseif target:getLostHp()<1 then return false end
		return true
	else
		if self:isWeak(target) then return false end
		if damage.damage > 1 or self:hasHeavySlashDamage(self.player, damage.card, target) then return false end
		if target:getArmor() and self:evaluateArmor(target:getArmor(), target)>3 then return true end
		local num = target:getHandcardNum()
		if self.player:hasSkill("tieji") or (self.player:hasSkill("liegong")
			and (num >= self.player:getHp() or num <= self.player:getAttackRange())) then return false end
		if target:hasSkill("tuntian") then return false end
		if self:hasSkills(sgs.need_kongcheng, target) then return false end
		if target:getCards("he"):length()<4 and target:getCards("he"):length()>1 then return true end
		return false
	end
end

function sgs.ai_slash_weaponfilter.GudingBlade(to)
	return to:isKongcheng()
end

function sgs.ai_weapon_value.GudingBlade(self, enemy)
	if not enemy then return end
	local value = 2
	if enemy:getHandcardNum() < 1 then value = 4 end
	return value
end

sgs.ai_skill_cardask["@Axe"] = function(self, data, pattern, target)
	if target and self:isFriend(target) then return "." end
	local effect = data:toSlashEffect()
	local allcards = self.player:getCards("he")
	allcards = sgs.QList2Table(allcards)
	if self:hasHeavySlashDamage(self.player, effect.slash, target) 
	  or #allcards - 3 >= self.player:getHp() 
	  or (self.player:hasSkill("kuanggu") and self.player:isWounded() and self.player:distanceTo(effect.to) == 1)
	  or (effect.to:getHp() == 1 and not effect.to:hasSkill("buqu")) 
	  or (self:needKongcheng() and self.player:getHandcardNum() > 0)
	  or (self:hasSkills(sgs.lose_equip_skill, self.player) and self.player:getEquips():length() > 1 and self.player:getHandcardNum() < 2) then
		local hcards = self.player:getCards("h")
		hcards = sgs.QList2Table(hcards)
		self:sortByKeepValue(hcards)
		local cards = {}
		local hand, armor, def, off = 0, 0, 0, 0
		if self:needToThrowArmor() then
			table.insert(cards, self.player:getArmor():getEffectiveId())
			armor = 1
		end
		if (self:hasSkills(sgs.need_kongcheng) or not self:hasLoseHandcardEffective()) and self.player:getHandcardNum() > 0 then
			hand = 1
			for _, card in ipairs(hcards) do
				table.insert(cards, card:getEffectiveId())
				if #cards == 2 then break end
			end
		end
		if #cards < 2 and self:hasSkills(sgs.lose_equip_skill, self.player) then
			if #cards < 2 and self.player:getOffensiveHorse() then
				off = 1
				table.insert(cards, self.player:getOffensiveHorse():getEffectiveId())
			end
			if #cards < 2 and self.player:getArmor() then
				armor = 1
				table.insert(cards, self.player:getArmor():getEffectiveId())
			end
			if #cards < 2 and self.player:getDefensiveHorse() then
				def = 1
				table.insert(cards, self.player:getDefensiveHorse():getEffectiveId())
			end
		end

		if #cards < 2 and hand < 1 and self.player:getHandcardNum() > 2 then
			hand = 1
			for _, card in ipairs(hcards) do
				table.insert(cards, card:getEffectiveId())
				if #cards == 2 then break end
			end
		end

		if #cards < 2 and off < 1 and self.player:getOffensiveHorse() then
			off = 1
			table.insert(cards, self.player:getOffensiveHorse():getEffectiveId())
		end
		if #cards < 2 and hand < 1 and self.player:getHandcardNum() > 0 then
			hand = 1
			for _, card in ipairs(hcards) do
				table.insert(cards, card:getEffectiveId())
				if #cards == 2 then break end
			end
		end
		if #cards < 2 and armor < 1 and self.player:getArmor() then
			armor = 1
			table.insert(cards, self.player:getArmor():getEffectiveId())
		end
		if #cards < 2 and def < 1 and self.player:getDefensiveHorse() then
			def = 1
			table.insert(cards, self.player:getDefensiveHorse():getEffectiveId())
		end

		if #cards == 2 then
			return "$"..table.concat(cards, "+")
		end
	end
end

sgs.ai_skill_cardask["@axe"] = sgs.ai_skill_cardask["@Axe"]

function sgs.ai_slash_weaponfilter.Axe(to, self)
	return self:getOverflow() > 0
end

function sgs.ai_weapon_value.Axe(self, enemy)
	if self:hasSkills("jiushi|jiuchi|luoyi|pojun",self.player) then return 6 end
	if enemy and enemy:getHp() < 3 then return 3 - enemy:getHp() end
end

sgs.ai_skill_cardask["blade-slash"] = function(self, data, pattern, target)
	if target and self:isFriend(target) and not (target:hasSkill("leiji") and getCardsNum("Jink", target) > 0) then
		return "."
	end
	for _, slash in ipairs(self:getCards("Slash")) do
		if self:slashIsEffective(slash, target) and (self:isWeak(target) or self:getOverflow() > 0) then
			return slash:toString()
		end 
	end
	return "."
end

function sgs.ai_weapon_value.Blade(self, enemy)
	if not enemy then return self:getCardsNum("Slash") end
end

function sgs.ai_cardsview.Spear(class_name, player)
	if class_name == "Slash" then
		local cards = player:getCards("he")	
		cards = sgs.QList2Table(cards)
		for _, acard in ipairs(cards) do
			if isCard("Slash", acard, player) then return end
		end
		local cards = player:getCards("h")	
		cards=sgs.QList2Table(cards)
		local newcards = {}
		for _, card in ipairs(cards) do
			if not card:isKindOf("Peach") and not (card:isKindOf("ExNihilo") and player:getPhase() == sgs.Player_Play) then table.insert(newcards, card) end
		end
		if #newcards<2 then return nil end

		local suit1 = newcards[1]:getSuitString()
		local card_id1 = newcards[1]:getEffectiveId()

		local suit2 = newcards[2]:getSuitString()
		local card_id2 = newcards[2]:getEffectiveId()

		local suit="no_suit"
		if newcards[1]:isBlack() == newcards[2]:isBlack() then suit = suit1 end
		
		local card_str
		if sgs.Sanguosha:getVersion() <= "20121221" then
			card_str = ("slash:Spear[%s:%s]=%d+%d"):format(suit, 0, card_id1, card_id2)
		else
			card_str = ("slash:Spear[to_be_decided:0]=%d+%d"):format(card_id1, card_id2)
		end

		return card_str
	end
end

local Spear_skill={}
Spear_skill.name="Spear"
table.insert(sgs.ai_skills,Spear_skill)
Spear_skill.getTurnUseCard=function(self,inclusive)
	local handcards = sgs.QList2Table(self.player:getCards("h"))
	local cards = {}

	for _, acard in ipairs(handcards) do
		if isCard("Slash", acard, self.player) then return end
	end

	for _, card in ipairs(handcards) do
		if not card:isKindOf("Peach") and not (card:isKindOf("ExNihilo") and self.player:getPhase() == sgs.Player_Play) then table.insert(cards, card) end
	end

	if #cards < self.player:getHp() and not self:hasHeavySlashDamage(self.player) and not self:hasSkills("kongcheng|lianying|paoxiao",self.player) then return nil end
	if #cards<2 then return nil end

	self:sortByUseValue(cards,true)

	local suit1 = cards[1]:getSuitString()
	local card_id1 = cards[1]:getEffectiveId()
	
	local suit2 = cards[2]:getSuitString()
	local card_id2 = cards[2]:getEffectiveId()

	local suit="no_suit"
	if cards[1]:isBlack() == cards[2]:isBlack() then suit = suit1 end
	
	if cards[1]:isBlack() and cards[2]:isBlack() then
		local black_slash = sgs.Sanguosha:cloneCard("slash", sgs.Card_Spade, 0)
		local nosuit_slash = sgs.Sanguosha:cloneCard("slash", sgs.Card_NoSuit, 0)
		
		self:sort(self.enemies, "defenseSlash")
		for _, enemy in ipairs(self.enemies) do
			if not self:slashProhibit(nosuit_slash, enemy) and self:slashIsEffective(nosuit_slash, enemy) and self:canAttack(enemy) 
					and self:slashProhibit(black_slash, enemy) and self:isWeak(enemy) and self.player:canSlash(enemy, nil, true)
					and not (enemy:hasSkill("kongcheng") and enemy:isKongcheng()) then
				local redcards, blackcards = {}, {}
				for _, acard in ipairs(cards) do
					if acard:isBlack() then table.insert(blackcards, acard) else table.insert(redcards, acard) end
				end
				if #redcards == 0 then break end
				
				local redcard, othercard

				self:sortByUseValue(blackcards, true)
				self:sortByUseValue(redcards, true)				
				redcard = redcards[1]

				othercard = #blackcards > 0 and blackcards[1] or redcards[2]
				if redcard and othercard then
					suit1 = redcard:getSuitString()
					card_id1 = redcard:getEffectiveId()
					suit2 = othercard:getSuitString()
					card_id2 = othercard:getEffectiveId()
					suit = othercard:isRed() and suit1 or "no_suit"
					break
				end				
			end
		end

	end

	local card_str
	if sgs.Sanguosha:getVersion() <= "20121221" then
		card_str = ("slash:Spear[%s:%s]=%d+%d"):format(suit, 0, card_id1, card_id2)
	else
		card_str = ("slash:Spear[to_be_decided:0]=%d+%d"):format(card_id1, card_id2)
	end

	local slash = sgs.Card_Parse(card_str)

	return slash	
end

function sgs.ai_slash_weaponfilter.Fan(to)
	local armor = to:getArmor()
	return armor and (armor:isKindOf("Vine") or armor:isKindOf("GaleShell"))
end

sgs.ai_skill_invoke.KylinBow = function(self, data)
	local damage = data:toDamage()
	if damage.from:hasSkill("kuangfu") and damage.to:getCards("e"):length() == 1 then return false end
	if self:hasSkills(sgs.lose_equip_skill, damage.to) then
		return self:isFriend(damage.to)
	end
	return self:isEnemy(damage.to)
end

function sgs.ai_slash_weaponfilter.KylinBow(to)
	if to:getDefensiveHorse() then return true else return false end
end

function sgs.ai_weapon_value.KylinBow(self, target)
	if not target then
		for _, enemy in ipairs(self.enemies) do
			if enemy:getOffensiveHorse() or enemy:getDefensiveHorse() then return 1 end
		end
	end
end

sgs.ai_skill_invoke.EightDiagram = function(self, data)
	local dying = 0
	local handang = self.room:findPlayerBySkillName("nosjiefan")
	for _, aplayer in sgs.qlist(self.room:getAlivePlayers()) do
		if aplayer:getHp() < 1 and not aplayer:hasSkill("buqu") then dying = 1 break end
	end
	if handang and self:isFriend(handang) and dying > 0 then return false end
	if self.player:hasFlag("dahe") then return false end
	if sgs.hujiasource and self:isEnemy(sgs.hujiasource) then return false end
	if sgs.lianlisource and self:isEnemy(sgs.lianlisource) then return false end
	if self.player:hasSkill("tiandu") then return true end
	if self:hasSkills("guidao", self.enemies) and self:getFinalRetrial(sgs.hujiasource) == 2 then
		local zhangjiao = self.room:findPlayerBySkillName("guidao")
		return getKnownCard(zhangjiao, "black", false, "he") > 1
	end	
	if self:getDamagedEffects(self.player) or self.player:getHp() > getBestHp(self.player) then return false end
	return true
end

function sgs.ai_armor_value.EightDiagram(player, self)
	local haszj = self:hasSkills("guidao", self:getEnemies(player))
	if haszj then 
		return 2
	end
	if self:hasSkills("tiandu|leiji|noszhenlie|gushou", player) then 
		return 5
	end
	
	if self.role == "loyalist" and self.player:getKingdom()=="wei" and not self.player:hasSkill("bazhen") and getLord(self.player) and getLord(self.player):hasLordSkill("hujia") then
		return 5
	end

	return 4 
end

function sgs.ai_armor_value.RenwangShield(player, self)
	if player:hasSkill("yizhong") then return 0 end
	if player:hasSkill("bazhen") then return 0 end
	if player:hasSkill("leiji") and getKnownCard(player, "Jink", true) > 1 then return 0 end
	return 4.5
end

function sgs.ai_armor_value.SilverLion(player, self)
	if self:hasWizard(self:getEnemies(player), true) then
		for _, player in sgs.qlist(self.room:getAlivePlayers()) do
			if player:containsTrick("lightning") then return 5 end
		end
	end
	return 1
end

sgs.ai_use_priority.OffensiveHorse = 2.69
sgs.ai_use_priority.Halberd = 2.685
sgs.ai_use_priority.KylinBow = 2.68
sgs.ai_use_priority.Blade = 2.675
sgs.ai_use_priority.GudingBlade = 2.67
sgs.ai_use_priority.DoubleSword =2.665
sgs.ai_use_priority.Spear = 2.66
sgs.ai_use_priority.IceSword = 2.65
sgs.ai_use_priority.QinggangSword = 2.645
sgs.ai_use_priority.Axe = 2.64
sgs.ai_use_priority.Crossbow = 2.63
sgs.ai_use_priority.SilverLion = 0.9
sgs.ai_use_priority.EightDiagram = 0.8
sgs.ai_use_priority.RenwangShield = 0.85
sgs.ai_use_priority.DefensiveHorse = 2.75

sgs.dynamic_value.damage_card.ArcheryAttack = true
sgs.dynamic_value.damage_card.SavageAssault = true

sgs.ai_use_value.ArcheryAttack = 3.8
sgs.ai_use_priority.ArcheryAttack = 3.5
sgs.ai_use_value.SavageAssault = 3.9
sgs.ai_use_priority.SavageAssault = 3.5

sgs.ai_skill_cardask.aoe = function(self, data, pattern, target, name)
	if sgs.ai_skill_cardask.nullfilter(self, data, pattern, target) then return "." end

	local aoe = sgs.Sanguosha:cloneCard(name, sgs.Card_NoSuit, 0)
	local menghuo = self.room:findPlayerBySkillName("huoshou")
	local attacker = target
	if menghuo and aoe:isKindOf("SavageAssault") then attacker = menghuo end

	if not self:damageIsEffective(nil, nil, attacker) then return "." end
	if self:getDamagedEffects(self.player, attacker) or self.player:getHp() > getBestHp(self.player) then return "." end

	if self.player:hasSkill("wuyan") and not attacker:hasSkill("jueqing") then return "." end
	if attacker:hasSkill("wuyan") and not attacker:hasSkill("jueqing") then return "." end
	if self.player:getMark("@fenyong") > 0 and not attacker:hasSkill("jueqing") then return "." end

	if not attacker:hasSkill("jueqing") and self.player:hasSkill("jianxiong") and self:getAoeValue(aoe) > -10
		and (self.player:getHp() > 1 or self:getAllPeachNum() > 0) and not self.player:containsTrick("indulgence") then return "." end
end


sgs.ai_skill_cardask["savage-assault-slash"] = function(self, data, pattern, target)
	return sgs.ai_skill_cardask.aoe(self, data, pattern, target, "savage_assault")
end

sgs.ai_skill_cardask["archery-attack-jink"] = function(self, data, pattern, target)
	return sgs.ai_skill_cardask.aoe(self, data, pattern, target, "archery_attack")
end

sgs.ai_keep_value.Nullification = 3
sgs.ai_use_value.Nullification = 8

function SmartAI:useCardAmazingGrace(card, use)
	if self.player:hasSkill("noswuyan") then use.card = card  return end
	if (self.role == "lord" or self.role == "loyalist") and sgs.turncount <= 2 and self.player:getSeat() <= 3 and self.player:aliveCount() > 5 then return end
	local value = 1
	local suf, coeff = 0.8, 0.8
	if self:hasSkills(sgs.need_kongcheng) and self.player:getHandcardNum() == 1 or self.player:hasSkill("jizhi") then
		suf = 0.6
		coeff = 0.6
	end
	for _, player in sgs.qlist(self.room:getOtherPlayers(self.player)) do
		local index = 0
		if self:isFriend(player) then index = 1 elseif self:isEnemy(player) then index = -1 end
		value = value + index * suf
		if value < 0 then return end
		suf = suf * coeff
	end
	use.card = card
end

sgs.ai_use_value.AmazingGrace = 3
sgs.ai_keep_value.AmazingGrace = -1
sgs.ai_use_priority.AmazingGrace = 1.2

function SmartAI:willUseGodSalvation(card)
	if not card then self.room:writeToConsole(debug.traceback()) return false end
	local good, bad = 0, 0
	local wounded_friend = 0
	local wounded_enemy = 0
	if self.player:hasSkill("noswuyan") and self.player:isWounded() then return true end
	
	if self:hasSkills("jizhi") then good = good + 6 end
	if self:hasSkills("kongcheng|lianying") and self.player:getHandcardNum() == 1 then good = good + 15 end

	local liuxie = self.room:findPlayerBySkillName("huangen")
	if liuxie then
		if self:isFriend(self.player, liuxie) then
			good = good + 5 * liuxie:getHp()
		else
			bad = bad + 5 * liuxie:getHp()
		end
	end

	for _, friend in ipairs(self.friends) do
		good = good + 10 * getCardsNum("Nullification", friend)
		if not ((friend:hasSkill("zhichi") and self.room:getTag("Zhichi"):toString() == friend:objectName()) or friend:hasSkill("noswuyan")) then					
			if friend:isWounded() then
				wounded_friend = wounded_friend + 1
				good = good + 10
				if friend:isLord() then good = good + 11/(friend:getHp() + 0.1) end
				if self:hasSkills(sgs.masochism_skill, friend) then
					good = good + 5
				end
				if friend:getHp() <= 1 and self:isWeak(friend) then
					good = good + 5
					if friend:isLord() then good = good + 10 end	
				else
					if friend:isLord() then good = good + 5 end
				end
			elseif friend:hasSkill("danlao") then good = good + 5
			end
		end
	end

	for _, enemy in ipairs(self.enemies) do
		bad = bad + 10 * getCardsNum("Nullification", enemy)
		if not ((enemy:hasSkill("zhichi") and self.room:getTag("Zhichi"):toString() == enemy:objectName()) or enemy:hasSkill("noswuyan")) then
			if enemy:isWounded() then
				wounded_enemy = wounded_enemy + 1
				bad = bad + 10
				if enemy:isLord() then
					bad = bad + 11/(enemy:getHp() + 0.1)
				end
				if self:hasSkills(sgs.masochism_skill, enemy) then
					bad = bad + 5
				end
				if enemy:getHp() <= 1 and self:isWeak(enemy) then
					bad = bad + 5
					if enemy:isLord() then bad = bad + 10 end
				else
					if enemy:isLord() then bad = bad + 5 end
				end
			elseif enemy:hasSkill("danlao") then bad = bad + 5
			end
		end
	end
	return (good - bad > 5 and wounded_friend > 0)  or (wounded_friend == 0 and wounded_enemy == 0 and self:hasSkills("jizhi"))
end

function SmartAI:useCardGodSalvation(card, use)	
	if self:willUseGodSalvation(card) then
		use.card = card
	end
end

sgs.ai_use_priority.GodSalvation = 1.1
sgs.dynamic_value.benefit.GodSalvation = true

function SmartAI:useCardDuel(duel, use)
	if self.player:hasSkill("wuyan") and not self.player:hasSkill("jueqing") then return end
	if self.player:hasSkill("noswuyan") then return end

	local enemies = self:exclude(self.enemies, duel)
	local friends = self:exclude(self.friends_noself, duel)
	local n1 = self:getCardsNum("Slash")
	local huatuo = self.room:findPlayerBySkillName("jijiu")
	local targets = {}

	local canUseDuelTo=function(target)
		return self:hasTrickEffective(duel, target) and self:damageIsEffective(target,sgs.DamageStruct_Normal) and not self.room:isProhibited(self.player, target, duel)
	end

	for _, friend in ipairs(friends) do
		if friend:hasSkill("jieming") and canUseDuelTo(friend) and self.player:hasSkill("rende") and (huatuo and self:isFriend(huatuo)) then
			table.insert(targets, friend)
		end
	end
	
	for _, enemy in ipairs(enemies) do
		if self.player:hasFlag("duelTo" .. enemy:objectName()) and enemy:isAlive() and canUseDuelTo(enemy) then			
			table.insert(targets, enemy)
		end
	end
	
	local cmp = function(a, b)
		local v1 = getCardsNum("Slash", a)
		local v2 = getCardsNum("Slash", b)

		if self:getDamagedEffects(a, self.player) then v1 = v1 + 20 end
		if self:getDamagedEffects(b, self.player) then v2 = v2 + 20 end

		if not self:isWeak(a) and a:hasSkill("jianxiong") and not self.player:hasSkill("jueqing") then v1 = v1 + 10 end
		if not self:isWeak(b) and b:hasSkill("jianxiong") and not self.player:hasSkill("jueqing") then v2 = v2 + 10 end

		if a:getHp() > getBestHp(a) then v1 = v1 + 5 end
		if b:getHp() > getBestHp(b) then v2 = v2 + 5 end

		if self:hasSkills(sgs.masochism_skill, a) then v1 = v1 + 5 end
		if self:hasSkills(sgs.masochism_skill, b) then v2 = v2 + 5 end		

		if not self:isWeak(a) and a:hasSkill("jiang") then v1 = v1 + 5 end
		if not self:isWeak(b) and b:hasSkill("jiang") then v2 = v2 + 5 end

		if a:hasLordSkill("jijiang") then v1 = v1 + 10 end
		if b:hasLordSkill("jijiang") then v2 = v2 + 10 end

		if v1 == v2 then return sgs.getDefenseSlash(a) < sgs.getDefenseSlash(b) end

		return v1 < v2
	end
	
	table.sort(enemies, cmp)

	for _, enemy in ipairs(enemies) do
		local useduel 
		local n2 =getCardsNum("Slash",enemy)
		if sgs.card_lack[enemy:objectName()]["Slash"] == 1 then n2 = 0 end
		useduel = n1 >= n2 or self.player:getHp() > getBestHp(self.player) 
					or self:getDamagedEffects(self.player, enemy) or (n2 < 1 and sgs.isGoodHp(self.player))
					or ((self:hasSkills("jianxiong") or self.player:getMark("shuangxiong") > 0) and sgs.isGoodHp(self.player))

		if self:objectiveLevel(enemy) > 3 and canUseDuelTo(enemy) and not self:cantbeHurt(enemy) and useduel and sgs.isGoodTarget(enemy, enemies, self) then
			table.insert(targets, enemy)
		end
	end
	
	if #targets > 0 then

		local godsalvation = self:getCard("GodSalvation")
		if godsalvation and godsalvation:getId()~= duel:getId() and self:willUseGodSalvation(godsalvation) then
			use.card = godsalvation return
		end

		local targets_num = 1 + sgs.Sanguosha:correctCardTarget(sgs.TargetModSkill_ExtraTarget, self.player, duel)
		local enemySlash = 0
		local setFlag = false

		use.card = duel
		
		for i = 1, #targets, 1 do
			local n2 =getCardsNum("Slash", targets[i])
			if sgs.card_lack[targets[i]:objectName()]["Slash"] == 1 then n2 = 0 end
			if self:isEnemy(targets[i]) then enemySlash = enemySlash + n2 end

			if use.to then				
				if i == 1 then
					use.to:append(targets[i])
					self:speak("duel", self.player:isFemale())					
				elseif n1 >= enemySlash then
					use.to:append(targets[i])					
				end
				if not setFlag and self.player:getPhase() == sgs.Player_Play and self:isEnemy(targets[i]) then 
					self.player:setFlags("duelTo" .. targets[i]:objectName())
					setFlag = true
				end
				if use.to:length() == targets_num then return end
			end
		end		
	end
	
end

sgs.ai_card_intention.Duel=function(self, card,from,tos,source)
	if sgs.ai_lijian_effect then 
		sgs.ai_lijian_effect = false
		return
	end
	sgs.updateIntentions(from, tos, 80)
end

sgs.ai_use_value.Duel = 3.7
sgs.ai_use_priority.Duel = 2.9
sgs.ai_keep_value.Duel = 1.7

sgs.dynamic_value.damage_card.Duel = true

sgs.ai_skill_cardask["duel-slash"] = function(self, data, pattern, target)
	if sgs.ai_skill_cardask.nullfilter(self, data, pattern, target) then return "." end
	if self.player:hasFlag("will_wake") then return "." end
	if (target:hasSkill("wuyan") or self.player:hasSkill("wuyan")) and not target:hasSkill("jueqing") then return "." end
	if self.player:getMark("@fenyong") >0 and self.player:hasSkill("fenyong") and not target:hasSkill("jueqing") then return "." end
	
	if self:cantbeHurt(target) then return "." end
	if self.player:getPhase()==sgs.Player_Play then return self:getCardId("Slash") end
	
	if self:isFriend(target) and target:hasSkill("rende") and self.player:hasSkill("jieming") then return "." end
	if self:isEnemy(target) and not self:isWeak() and self:getDamagedEffects(self.player, target) then return "." end

	if self:isFriend(target) then 
		if self:getDamagedEffects(self.player,target) or self.player:getHp() > getBestHp(self.player) then return "." end
		if self:getDamagedEffects(target,self.player) or target:getHp() > getBestHp(target) then
			return self:getCardId("Slash")
		else
			if target:isLord() and not sgs.isLordInDanger() and not sgs.isGoodHp(self.player) then return self:getCardId("Slash") end
			if self.player:isLord() and sgs.isLordInDanger() then return self:getCardId("Slash") end			
			return "."
		end
	end
			
	if (not self:isFriend(target) and self:getCardsNum("Slash") >= getCardsNum("Slash", target))
		or (target:getHp() > 2 and self.player:getHp() <= 1 and self:getCardsNum("Peach") == 0 and not self.player:hasSkill("buqu")) then
		return self:getCardId("Slash")
	else return "." end
	
end

function SmartAI:useCardExNihilo(card, use)
	use.card = card
	if not use.isDummy then
		self:speak("lucky")
	end
end

sgs.ai_card_intention.ExNihilo = -80

sgs.ai_keep_value.ExNihilo = 3.6
sgs.ai_use_value.ExNihilo = 10
sgs.ai_use_priority.ExNihilo = 9.3

sgs.dynamic_value.benefit.ExNihilo = true

function SmartAI:getDangerousCard(who)
	local weapon = who:getWeapon()
	local armor = who:getArmor()
	if weapon and weapon:isKindOf("Crossbow") then 
		for _, friend in ipairs(self.friends) do
			if who:distanceTo(friend) <= 1 then
				return weapon:getEffectiveId()
			end
		end
	end
	if (weapon and weapon:isKindOf("Spear") and who:hasSkill("paoxiao") and who:getHandcardNum() >=1 ) then return weapon:getEffectiveId() end
	if weapon and weapon:isKindOf("Axe") and self:hasSkills("luoyi|pojun|jiushi|jiuchi|jie|wenjiu|shenli|jieyuan", who) then
		return weapon:getEffectiveId()
	end
	if armor and armor:isKindOf("EightDiagram") and who:hasSkill("leiji") then return armor:getEffectiveId() end
	if (weapon and weapon:isKindOf("SPMoonSpear") and self:hasSkills("guidao|longdan|guicai|jilve|huanshi|qingguo|kanpo", who)) then
		return weapon:getEffectiveId()
	end
	if (weapon and who:hasSkill("liegong")) then return weapon:getEffectiveId() end
end

function SmartAI:getValuableCard(who)
	local weapon = who:getWeapon()
	local armor = who:getArmor()
	local offhorse = who:getOffensiveHorse()
	local defhorse = who:getDefensiveHorse()
	self:sort(self.friends, "hp")
	local friend 
	if #self.friends > 0 then friend = self.friends[1] end
	if friend and self:isWeak(friend) and who:distanceTo(friend) <= who:getAttackRange() and not self:doNotDiscard(who, "e", true) then
		if weapon and (who:distanceTo(friend) > 1) then
			return weapon:getEffectiveId()
		end
		if offhorse and who:distanceTo(friend) > 1 then
			return offhorse:getEffectiveId()
		end
	end

	if weapon then
		if (weapon:isKindOf("MoonSpear") and who:hasSkill("keji") and who:getHandcardNum() > 5)
		  or self:hasSkills("qiangxi|zhulou|taichen", who) then
			return weapon:getEffectiveId()
		end 
	end
	if defhorse and not self:doNotDiscard(who, "e") then
		return defhorse:getEffectiveId()
	end

	if armor and self:evaluateArmor(armor,who) > 3
	  and not self:needToThrowArmor(who)
	  and not self:doNotDiscard(who, "e") then
		return armor:getEffectiveId()
	end

	if offhorse then
		if self:hasSkills("nosqianxi|kuanggu|duanbing|qianxi", who) then
			return offhorse:getEffectiveId()
		end
	end

	local equips = sgs.QList2Table(who:getEquips())
	for _,equip in ipairs(equips) do
		if who:hasSkill("longhun") and not equip:getSuit() == sgs.Card_Diamond then  return equip:getEffectiveId() end
		if self:hasSkills("guose|yanxiao", who) and equip:getSuit() == sgs.Card_Diamond then  return equip:getEffectiveId() end
		if self:hasSkills("shensu|mingce|beige|yuanhu|gongqi|nosgongqi|yanzheng|qingcheng|shuijian|neoluoyi", who) then
			return equip:getEffectiveId()
		end
		if who:hasSkill("baobian") and who:getHp() <= 2 then return  equip:getEffectiveId() end
		if self:hasSkills("qixi|duanliang|yinling|guidao", who) and equip:isBlack() then  return equip:getEffectiveId() end
		if self:hasSkills("wusheng|jijiu|xueji|nosfuhun", who) and equip:isRed() then  return equip:getEffectiveId() end
	end

	if weapon then
		if not self:doNotDiscard(who, "e", true) then
			for _,friend in ipairs(self.friends) do
				if (who:distanceTo(friend) <= who:getAttackRange()) and (who:distanceTo(friend) > 1) then
					return weapon:getEffectiveId()
				end
			end
		end
	end

	if offhorse then
		if not self:doNotDiscard(who, "e", true) then
		else
			for _,friend in ipairs(self.friends) do
				if who:distanceTo(friend) == who:getAttackRange() and who:getAttackRange() > 1 then
					return offhorse:getEffectiveId()
				end
			end
		end
	end
end

function SmartAI:useCardSnatchOrDismantlement(card, use)
	local name = card:objectName()
	if self.player:hasSkill("noswuyan") then return end
	local players = self.room:getOtherPlayers(self.player)
	local tricks
	players = self:exclude(players, card)
	for _, player in ipairs(players) do
		if not player:getJudgingArea():isEmpty() and self:hasTrickEffective(card, player)
		  and ((player:containsTrick("lightning") and self:getFinalRetrial(player) == 2) or #self.enemies == 0) then 
			use.card = card
			if use.to then 
				tricks = player:getCards("j")
				for _, trick in sgs.qlist(tricks) do
					if trick:isKindOf("Lightning") then
						sgs.ai_skill_cardchosen[name] = trick:getEffectiveId()
					end
				end
				use.to:append(player)
			end
			return
		end
	end
	
	local enemies = {}

	if #self.enemies == 0 and self:getOverflow() > 0 then
		local lord = getLord(self.player)		
		for _, player in ipairs(players) do
			if not self:isFriend(player) then
				if lord and self.player:objectName() == lord:objectName() then
					if player:getKingdom() ~= lord:getKingdom() and not lord:hasSkill("yongsi") then table.insert(enemies, player) end
				elseif lord and player:objectName() ~= lord:objectName() then 
					table.insert(enemies, player)
				else
					if not lord then table.insert(enemies, player) end
				end
			end
		end

		enemies = self:exclude(enemies, card)		
		self:sort(enemies, "defenseSlash")
		enemies = sgs.reverse(enemies)
	else
		enemies = self:exclude(self.enemies, card)
		self:sort(enemies, "defenseSlash")
	end

	self:sort(self.friends_noself, "defense")
	local friends = self:exclude(self.friends_noself, card)
	local hasLion, target
	for _, enemy in ipairs(enemies) do
		if self:getDangerousCard(enemy) and self:hasTrickEffective(card, enemy) then
			use.card = card
			if use.to then
				sgs.ai_skill_cardchosen[name] = self:getDangerousCard(enemy)
				use.to:append(enemy)
				self:speak("hostile", self.player:isFemale())
			end
			return
		end
	end

	for _, friend in ipairs(friends) do
		if (friend:containsTrick("indulgence") or friend:containsTrick("supply_shortage")) and self:hasTrickEffective(card, friend) 
				and not (friend:hasSkill("qiaobian") and not friend:isKongcheng()) and not friend:containsTrick("YanxiaoCard") then
			use.card = card
			if use.to then 
				tricks = friend:getJudgingArea()
				for _, trick in sgs.qlist(tricks) do
					if trick:isKindOf("Indulgence") then
						if friend:getHp() <= friend:getHandcardNum() or friend:isLord() or name == "snatch" then
							sgs.ai_skill_cardchosen[name] = trick:getEffectiveId()
							break
						end
					end
					if trick:isKindOf("SupplyShortage") then
						sgs.ai_skill_cardchosen[name] = trick:getEffectiveId()
						break
					end
					if trick:isKindOf("Indulgence") then
						sgs.ai_skill_cardchosen[name] = trick:getEffectiveId()
						break
					end
				end
				use.to:append(friend) 
			end
			
			return
		end
		if self:hasTrickEffective(card, friend) and self:needToThrowArmor(friend) then
			hasLion = true
			target = friend
		end
	end
	

	local new_enemies = table.copyFrom(enemies)
	local compare_JudgingArea = function(a, b)
		return a:getJudgingArea():length() > b:getJudgingArea():length()
	end
	table.sort(new_enemies, compare_JudgingArea)	
	local yanxiao_card, yanxiao_target, yanxiao_prior
	for _, enemy in ipairs(new_enemies) do
		for _, acard in sgs.qlist(enemy:getJudgingArea()) do
			if acard:isKindOf("YanxiaoCard") and self:hasTrickEffective(card, enemy) then
				yanxiao_card = acard
				yanxiao_target = enemy
				if enemy:containsTrick("indulgence") or enemy:containsTrick("supply_shortage") then yanxiao_prior = true end
				break
			end
		end
		if yanxiao_card and yanxiao_target then break end
	end
	if yanxiao_prior and yanxiao_card and yanxiao_target then
		use.card = card
		if use.to then 
			sgs.ai_skill_cardchosen[name] = yanxiao_card:getEffectiveId()
			use.to:append(yanxiao_target)
		end
		return
	end	
	
	for _, enemy in ipairs(enemies) do
		local cards = sgs.QList2Table(enemy:getHandcards())
		local flag = string.format("%s_%s_%s", "visible", self.player:objectName(), enemy:objectName())
		if #cards <= 2 and self:hasTrickEffective(card, enemy) and not self:doNotDiscard(enemy, "h", true) then
			for _, cc in ipairs(cards) do
				if (cc:hasFlag("visible") or cc:hasFlag(flag)) and (cc:isKindOf("Peach") or cc:isKindOf("Analeptic")) then
					use.card = card
					if use.to then
						sgs.ai_skill_cardchosen[name] = self:getCardRandomly(enemy, "h")
						use.to:append(enemy)
						self:speak("hostile", self.player:isFemale())
					end
					return
				end
			end
		end
	end

	for _, enemy in ipairs(enemies) do
		if enemy:hasEquip() and self:hasTrickEffective(card, enemy) and not self:doNotDiscard(enemy) then			
			if self:hasSkills("jijiu|qingnang|qiaobian|jieyin|beige|nosmiji|fanjian|neofanjian|tuxi|" ..
			  "buyi|weimu|anxu|guzheng|tongxin|xiliang|chouliang|shouye|qixi|manjuan", enemy) then
				local cardchosen
				if enemy:getDefensiveHorse() then cardchosen = enemy:getDefensiveHorse():getEffectiveId() end
				if not cardchosen and enemy:getArmor() and not self:needToThrowArmor(enemy) and not enemy:getArmor():isKindOf("SilverLion") then 
					cardchosen = enemy:getArmor():getEffectiveId() 
				end	
				if not cardchosen and enemy:getOffensiveHorse()
				  and ((enemy:hasSkill("jijiu") and enemy:getOffensiveHorse():isRed()) or enemy:hasSkill("beige")) then
					cardchosen = enemy:getOffensiveHorse():getEffectiveId()
				end
				if not cardchosen and enemy:getWeapon() 
				  and ((enemy:hasSkill("jijiu") and enemy:getWeapon():isRed()) or enemy:hasSkill("beige")) then
					cardchosen = enemy:getWeapon():getEffectiveId()
				end
				
				if not cardchosen and self:hasSkills("jijiu|qingnang|qiaobian|jieyin|buyi|manjuan", enemy)
				  and not enemy:isKongcheng() and enemy:getHandcardNum() <= 2 and not self:doNotDiscard(enemy, "h") then 
					cardchosen = self:getCardRandomly(enemy, "h") 
				end
				
				if cardchosen then				
					use.card = card
					if use.to then
						sgs.ai_skill_cardchosen[name] = cardchosen
						use.to:append(enemy)
						self:speak("hostile", self.player:isFemale())
					end
					return
				end
			end
		end
	end

	for _, enemy in ipairs(enemies) do
		if self:hasTrickEffective(card, enemy) and enemy:getArmor() and enemy:getArmor():isKindOf("EightDiagram") then
			use.card = card
			if use.to then
				sgs.ai_skill_cardchosen[name] = enemy:getArmor():getEffectiveId()
				use.to:append(enemy)
				self:speak("hostile", self.player:isFemale())
			end
			return
		end
	end
	
	for i= 1,2,1 do
		for _, enemy in ipairs(enemies) do
			if self:hasTrickEffective(card, enemy) and not self:needKongcheng(enemy) and not self:doNotDiscard(enemy) then
				if enemy:getHandcardNum() == i and sgs.getDefenseSlash(enemy) < 3 and enemy:getHp() <= 3 then
					local cardchosen
					if self.player:distanceTo(enemy) == self.player:getAttackRange() + 1 and enemy:getDefensiveHorse()
					  and not self:doNotDiscard(enemy, "e") then
						cardchosen = enemy:getDefensiveHorse():getEffectiveId()
					elseif enemy:getArmor() and not self:needToThrowArmor(enemy) and not self:doNotDiscard(enemy, "e") then
						cardchosen = enemy:getArmor():getEffectiveId()
					else
						cardchosen = self:getCardRandomly(enemy, "h")
					end
					use.card = card
					if use.to then
						sgs.ai_skill_cardchosen[name] = cardchosen
						use.to:append(enemy)
						self:speak("hostile", self.player:isFemale())
					end
					return
				end
			end
		end
	end

	if yanxiao_card and yanxiao_target then
		use.card = card
		if use.to then 
			sgs.ai_skill_cardchosen[name] = yanxiao_card:getEffectiveId()
			use.to:append(yanxiao_target)
		end
		return
	end
	
	for _, enemy in ipairs(enemies) do
		if self:getValuableCard(enemy) and self:hasTrickEffective(card, enemy) then
			use.card = card
			if use.to then
				sgs.ai_skill_cardchosen[name] = self:getValuableCard(enemy)
				use.to:append(enemy)
				self:speak("hostile", self.player:isFemale())
			end
			return
		end
	end

	if hasLion then
		use.card = card
		if use.to then 
			sgs.ai_skill_cardchosen[name] = target:getArmor():getEffectiveId()
			use.to:append(target) 
		end
		return
	end

	for _, enemy in ipairs(enemies) do
		if not self:doNotDiscard(enemy, "h") and self:hasTrickEffective(card, enemy) and self:hasSkills(sgs.cardneed_skill, enemy) then
			use.card = card
			if use.to then
				sgs.ai_skill_cardchosen[name] = self:getCardRandomly(enemy, "h")
				use.to:append(enemy)
				self:speak("hostile", self.player:isFemale())
			end
			return
		end
	end

	for _, enemy in ipairs(enemies) do
		if not self:doNotDiscard(enemy, "e") and self:hasTrickEffective(card, enemy) then
			local cardchosen
			if enemy:getDefensiveHorse() then
				cardchosen = enemy:getDefensiveHorse():getEffectiveId()
			elseif enemy:getArmor() and not self:needToThrowArmor(enemy) then
				cardchosen = enemy:getArmor():getEffectiveId()
			elseif enemy:getOffensiveHorse() then
				cardchosen = enemy:getOffensiveHorse():getEffectiveId()
			elseif enemy:getWeapon() then
				cardchosen = enemy:getWeapon():getEffectiveId()
			end
			use.card = card
			if use.to then
				sgs.ai_skill_cardchosen[name] = cardchosen
				use.to:append(enemy)
				self:speak("hostile", self.player:isFemale())
			end
			return
		end
	end

	if name == "snatch" or self:getOverflow() > 0 then
		for _, enemy in ipairs(enemies) do
			if self:hasTrickEffective(card, enemy) and not self:doNotDiscard(enemy, "he") then
				use.card = card
				if use.to then
					if not self:doNotDiscard(enemy, "e") then
						sgs.ai_skill_cardchosen[name] = self:getCardRandomly(enemy, "e")
					else 
						sgs.ai_skill_cardchosen[name] = self:getCardRandomly(enemy, "h") 
					end
					use.to:append(enemy)
					self:speak("hostile", self.player:isFemale())
				end
				return
			end
		end
	end
end

SmartAI.useCardSnatch = SmartAI.useCardSnatchOrDismantlement

sgs.ai_use_value.Snatch = 9
sgs.ai_use_priority.Snatch = 4.3
sgs.ai_keep_value.Snatch = 1.9

sgs.dynamic_value.control_card.Snatch = true
function sgs.ai_card_intention.Snatch()
	sgs.ai_snat_disma_effect = false
end

SmartAI.useCardDismantlement = SmartAI.useCardSnatchOrDismantlement

sgs.ai_use_value.Dismantlement = 5.6
sgs.ai_use_priority.Dismantlement = 4.4
sgs.ai_keep_value.Dismantlement = 1.8
function sgs.ai_card_intention.Dismantlement()
	sgs.ai_snat_disma_effect = false
end

sgs.dynamic_value.control_card.Dismantlement = true

function SmartAI:useCardCollateral(card, use)
	if self.player:hasSkill("noswuyan") then return end	
	local fromList = sgs.QList2Table(self.room:getOtherPlayers(self.player))
	local toList   = sgs.QList2Table(self.room:getAlivePlayers())

	local cmp = function(a, b)
		local alevel = self:objectiveLevel(a)
		local blevel = self:objectiveLevel(b)

		if alevel ~= blevel then return alevel > blevel end

		local anum = getCardsNum("Slash", a)
		local bnum = getCardsNum("Slash", b)

		if anum ~= bnum then return anum < bnum end
		return a:getHandcardNum() < b:getHandcardNum()
	end

	table.sort(fromList, cmp)
	self:sort(toList, "defense")

	local needCrossbow = false
	for _, enemy in ipairs(self.enemies) do
		if self.player:canSlash(enemy, nil) and self:objectiveLevel(enemy) > 3
				and sgs.isGoodTarget(enemy, self.enemies, self) and not self:slashProhibit(nil, enemy) then
			needCrossbow = true
			break
		end
	end

	needCrossbow = needCrossbow and self:getCardsNum("Slash", friend) > 2 and not self.player:hasSkill("paoxiao")

	if needCrossbow then
		for i = #fromList, 1, -1 do
			local friend = fromList[i]
			if friend:getWeapon() and friend:getWeapon():isKindOf("Crossbow")
				and not (friend:hasSkill("weimu") and card:isBlack())
				and not self.room:isProhibited(self.player, friend, card) then

				for _, enemy in ipairs(toList) do
					if friend:canSlash(enemy, nil) and friend:objectName() ~= enemy:objectName() then
						self.room:setPlayerFlag(self.player, "needCrossbow")
						use.card = card
						if use.to then use.to:append(friend) end
						if use.to then use.to:append(enemy) end
						return
					end
				end
			end
		end
	end
	
	local n = nil
	local final_enemy = nil
	for _, enemy in ipairs(fromList) do
		if not self.room:isProhibited(self.player, enemy, card)
			and self:hasTrickEffective(card, enemy)
			and not self:hasSkills(sgs.lose_equip_skill, enemy)
			and not (enemy:hasSkill("weimu") and card:isBlack())
			and not enemy:hasSkill("tuntian")
			and self:objectiveLevel(enemy) >= 0
			and enemy:getWeapon() then

			for _, enemy2 in ipairs(toList) do
				if enemy:canSlash(enemy2) and self:objectiveLevel(enemy2) > 3 and enemy:objectName() ~= enemy2:objectName() then
					n = 1
					final_enemy = enemy2
					break
				end
			end

			if not n then
				for _, enemy2 in ipairs(toList) do
					if enemy:canSlash(enemy2) and self:objectiveLevel(enemy2) <=3 and self:objectiveLevel(enemy2) >=0 and enemy:objectName() ~= enemy2:objectName() then
						n = 1
						final_enemy = enemy2
						break
					end
				end
			end

			if not n then
				for _, friend in ipairs(toList) do
					if enemy:canSlash(friend) and self:objectiveLevel(friend) < 0 and enemy:objectName() ~= friend:objectName() 
							and (self:needToLostHp(friend, enemy, true) or self:getDamagedEffects(friend, enemy, true)) then
						n = 1
						final_enemy = friend
						break
					end
				end
			end

			if not n then
				for _, friend in ipairs(toList) do
					if enemy:canSlash(friend) and self:objectiveLevel(friend) < 0 and enemy:objectName() ~= friend:objectName() 
							and (getKnownCard(friend, "Jink", true, "he") >= 2 or getCardsNum("Slash", enemy) < 1) then
						n = 1
						final_enemy = friend
						break
					end
				end
			end

			if n then 
				use.card = card
				if use.to then use.to:append(enemy) end
				if use.to then use.to:append(final_enemy) end
				return
			end
		end
		n = nil
	end

	for _, friend in ipairs(fromList) do
		if friend:getWeapon() and getCardsNum("Slash", friend) >= 1
			and not (friend:hasSkill("weimu") and card:isBlack())
			and self:objectiveLevel(friend) < 0
			and not self.room:isProhibited(self.player, friend, card) then

			for _, enemy in ipairs(toList) do
				if friend:canSlash(enemy, nil) and self:objectiveLevel(enemy) > 3 and friend:objectName() ~= enemy:objectName()
						and sgs.isGoodTarget(enemy, self.enemies, self) and not self:slashProhibit(nil, enemy) then
					use.card = card
					if use.to then use.to:append(friend) end
					if use.to then use.to:append(enemy) end
					return
				end
			end
		end
	end
	
	self:sortEnemies(toList)

	for _, friend in ipairs(fromList) do
		if friend:getWeapon() and (self:hasSkills(sgs.lose_equip_skill, friend) or friend:hasSkill("tuntian"))
			and not (friend:hasSkill("weimu") and card:isBlack())
			and self:objectiveLevel(friend) < 0
			and not (friend:getWeapon():isKindOf("Crossbow") and getCardsNum("Slash", to) > 1)
			and not self.room:isProhibited(self.player, friend, card) then

			for _, enemy in ipairs(toList) do
				if friend:canSlash(enemy, nil) and friend:objectName() ~= enemy:objectName() then
					use.card = card
					if use.to then use.to:append(friend) end
					if use.to then use.to:append(enemy) end
					return
				end
			end
		end
	end
end

sgs.ai_use_value.Collateral = 5.8
sgs.ai_use_priority.Collateral = 2.75

sgs.ai_card_intention.Collateral = function(self,card, from, tos)
	assert(#tos == 1)
	--借刀的关系值更新可能存在bug，先不更新
	sgs.ai_collateral = false
end

sgs.dynamic_value.control_card.Collateral = true

sgs.ai_skill_cardask["collateral-slash"] = function(self, data, pattern, target, target2)
	local current = self.room:getCurrent()
	if self:isFriend(current) and (current:hasFlag("needCrossbow") or 
			(self:getCardsNum("Slash", current) >= 2 and self.player:getWeapon():isKindOf("Crossbow"))) then
		if current:hasFlag("needCrossbow") then self.room:setPlayerFlag(current, "-needCrossbow") end
		return "."
	end

	if self:isFriend(target2) and target2:hasSkill("leiji") 
		and ( self:hasSuit("spade", true, target2) or target2:getHandcardNum() >= 3)
		and (getKnownCard(target2,"Jink",true) >= 1 or 
			(not self:isWeak(target2) and not self:isEquip("QinggangSword", self.player) and self:isEquip("EightDiagram",target2) )) then

		for _, slash in ipairs(self:getCards("Slash")) do
			if self:slashIsEffective(slash, target2) then 
				return slash:toString()
			end
		end		
	end

	if target2 and (self:getDamagedEffects(target2,self.player) or target2:getHp() > getBestHp(target2)) then		
		for _, slash in ipairs(self:getCards("Slash")) do
			if self:slashIsEffective(slash, target2) and self:isFriend(target2) then 
				return slash:toString()
			end 
			if not self:slashIsEffective(slash, target2, true) and self:isEnemy(target2) then 
				return slash:toString()
			end
		end
		for _, slash in ipairs(self:getCards("Slash")) do
			if not self:getDamagedEffects(target2, self.player, true) and self:isEnemy(target2) then 
				return slash:toString()
			end
		end
	end

	if target2 and not self:hasSkills(sgs.lose_equip_skill) and self:isEnemy(target2) then
		for _, slash in ipairs(self:getCards("Slash")) do
			if self:slashIsEffective(slash, target2) then 
				return slash:toString()
			end 
		end
	end
	if target2 and not self:hasSkills(sgs.lose_equip_skill) and self:isFriend(target2) then
		for _, slash in ipairs(self:getCards("Slash")) do
			if not self:slashIsEffective(slash, target2) then
				return slash:toString()
			end 
		end
		if (target2:getHp() > 2 or getCardsNum("Jink", target2) > 1) and not target2:getRole() == "lord" and self.player:getHandcardNum() > 1 then
			for _, slash in ipairs(self:getCards("Slash")) do
				return slash:toString()
			end 
		end
	end
	self:speak("collateral", self.player:isFemale())
	return "."
end

local function hp_subtract_handcard(a,b)
	local diff1 = a:getHp() - a:getHandcardNum()
	local diff2 = b:getHp() - b:getHandcardNum()

	return diff1 < diff2
end

function SmartAI:enemiesContainsTrick()
	local trick_all, possible_indul_enemy, possible_ss_enemy = 0, 0, 0
	local indul_num = self:getCardsNum("Indulgence")
	local ss_num = self:getCardsNum("SupplyShortage")
	
	local zhanghe = self.room:findPlayerBySkillName("qiaobian")
	if zhanghe and (not self:isEnemy(zhanghe) or zhanghe:isKongcheng() or not zhanghe:faceUp()) then zhanghe = nil end
	
	if self.player:hasSkill("guose") then
		for _, acard in sgs.qlist(self.player:getCards("he")) do
			if acard:getSuit() == sgs.Card_Diamond then indul_num = indul_num + 1 end
		end
	end	
	
	if self.player:hasSkill("duanliang") then
		for _, acard in sgs.qlist(self.player:getCards("he")) do
			if acard:isBlack() then ss_num = ss_num + 1 end
		end
	end
	
	for _, enemy in ipairs(self.enemies) do
		if not enemy:containsTrick("YanxiaoCard") and not (self:hasSkills("qiaobian", enemy) and enemy:getHandcardNum() > 0) 
		  and not self:hasSkills("keji|conghui", enemy) then
			if enemy:containsTrick("indulgence") and (not zhanghe or self:playerGetRound(enemy) >= self:playerGetRound(zhanghe)) then
				trick_all = trick_all + 1 
			else
				possible_indul_enemy = possible_indul_enemy + 1
			end
		end
		if not self:hasSkills("shensu|jisu", enemy) and (self.player:distanceTo(enemy) == 1 or self.player:hasSkill("duanliang") and self.player:distanceTo(enemy) <= 2) then
			if enemy:containsTrick("supply_shortage") and (not zhanghe or self:playerGetRound(enemy) >= self:playerGetRound(zhanghe)) then
				trick_all = trick_all + 1
			else
				possible_ss_enemy  = possible_ss_enemy + 1
			end
		end
	end
	
	indul_num = math.min(possible_indul_enemy, indul_num)
	ss_num = math.min(possible_ss_enemy, ss_num)
	trick_all = trick_all + indul_num + ss_num
	return trick_all
end

function SmartAI:playerGetRound(player, source, FriendorEnemy)
	if not player then return self.room:writeToConsole(debug.traceback()) end
	source = source or self.player
	if player:objectName() == source:objectName() then return 0 end
	local round = 0
	for i = 1 , self.room:alivePlayerCount() do
		if FriendorEnemy then
			if FriendorEnemy == "friend" and self:isFriend(source) then				
				round = round + 1
			elseif FriendorEnemy == "enemy" and not self:isFriend(source) then
				round = round + 1
			end
		else
			round = round + 1
		end
		if source:getNextAlive():objectName() == player:objectName() then break end
		source = source:getNextAlive()
	end
	return round
end

function SmartAI:useCardIndulgence(card, use)
	local enemies = {}

	if #self.enemies == 0 then
		if sgs.turncount == 0 and self.role == "lord" and not sgs.isRolePredictable() 
			and sgs.role_evaluation[self.player:getNextAlive():objectName()]["loyalist"] == 30 
			and not (self.player:hasLordSkill("shichou") and self.player:getNextAlive():getKingdom() == "shu") then
			enemies = self:exclude({self.player:getNextAlive()}, card)
		end
	else
		enemies = self:exclude(self.enemies, card)
	end	

	local zhanghe = self.room:findPlayerBySkillName("qiaobian")
	local zhanghe_seat = zhanghe and zhanghe:faceUp() and not zhanghe:isKongcheng() and self:isEnemy(zhanghe) and zhanghe:getSeat() or 0

	if #enemies == 0 then return end
	
	local getvalue = function(enemy)
		if enemy:containsTrick("indulgence") or enemy:containsTrick("YanxiaoCard") or self:hasSkills("qiaobian", enemy) and self:enemiesContainsTrick() <= 1 then return -100 end
		if zhanghe_seat > 0 and (self:playerGetRound(zhanghe) <= self:playerGetRound(enemy) and self:enemiesContainsTrick() <= 1 or not enemy:faceUp()) then
			return - 100 end

		local value = enemy:getHandcardNum() - enemy:getHp()

		if self:hasSkills("lijian|fanjian|neofanjian|dimeng|jijiu|jieyin|anxu|yongsi|zhiheng|manjuan|rende",enemy) then value = value + 10 end		
		if self:hasSkills("houyuan|qixi|qice|guose|duanliang|yanxiao|nosjujian|luoshen|jizhi|jilve|wansha|mingce|sizhan",enemy) then value = value + 5 end
		if self:hasSkills("guzheng|luoying|xiliang|guixin|lihun|yinling|gongxin|shenfen|ganlu|duoshi|jueji|zhenggong",enemy) then value = value + 3 end
		if self:isWeak(enemy) then value = value + 3 end
		if enemy:isLord() then value = value + 3 end

		if self:objectiveLevel(enemy) < 3 then value = value - 10 end
		if not enemy:faceUp() then value = value - 10 end
		if self:hasSkills("keji|shensu", enemy) then value = value - enemy:getHandcardNum() end
		if self:hasSkills("guanxing|xiuluo", enemy) then value = value - 5 end
		if self:hasSkills("lirang|longluo", enemy) then value = value - 5 end
		if self:hasSkills("tuxi|noszhenlie|guanxing|qinyin|zongshi|tiandu",enemy) then value = value - 3 end
		if enemy:hasSkill("conghui") then value = value - 20 end
		if self:needBear(enemy) then value = value - 20 end	
		if not sgs.isGoodTarget(enemy, self.enemies, self) then value = value - 1 end
		return value
	end

	local cmp = function(a,b)
		return getvalue(a) > getvalue(b)
	end

	table.sort(enemies, cmp)

	local target = enemies[1]
	if getvalue(target) > -100 then
		use.card = card
		if use.to then use.to:append(target) end
		return		
	end
end

sgs.ai_use_value.Indulgence = 8
sgs.ai_use_priority.Indulgence = 0.5
sgs.ai_card_intention.Indulgence = 120
sgs.ai_keep_value.Indulgence = 1.5

sgs.dynamic_value.control_usecard.Indulgence = true

function SmartAI:willUseLightning(card)
	if not card then self.room:writeToConsole(debug.traceback()) return false end
	if self.player:containsTrick("lightning") then return end
	if self.player:hasSkill("weimu") and card:isBlack() then return end
	if self.room:isProhibited(self.player, self.player, card) then return end

	local function hasDangerousFriend() 
		local hashy = false
		for _, aplayer in ipairs(self.enemies) do
			if aplayer:hasSkill("hongyan") then hashy = true break end
		end
		for _, aplayer in ipairs(self.enemies) do
			if aplayer:hasSkill("guanxing") or (aplayer:hasSkill("gongxin") and hashy) 
			or aplayer:hasSkill("xinzhan") then 
				if self:isFriend(aplayer:getNextAlive()) then return true end
			end
		end
		return false
	end
	
	if self:getFinalRetrial(self.player) == 2 then 
	return
	elseif self:getFinalRetrial(self.player) == 1 then
		return true
	elseif not hasDangerousFriend() then
		local players = self.room:getAllPlayers()
		players = sgs.QList2Table(players)

		local friends = 0
		local enemies = 0

		for _,player in ipairs(players) do
			if self:objectiveLevel(player) >= 4 and not player:hasSkill("hongyan")
			  and not (player:hasSkill("weimu") and card:isBlack()) then
				enemies = enemies + 1
			elseif self:isFriend(player) and not player:hasSkill("hongyan")
			  and not (player:hasSkill("weimu") and card:isBlack()) then
				friends = friends + 1
			end
		end

		local ratio

		if friends == 0 then ratio = 999
		else ratio = enemies/friends
		end

		if ratio > 1.5 then
			return true
		end
	end
end

function SmartAI:useCardLightning(card, use)	
	if self:willUseLightning(card) then
		use.card = card
	end
end

sgs.dynamic_value.lucky_chance.Lightning = true

sgs.ai_keep_value.Lightning = -1

sgs.ai_skill_askforag.amazing_grace = function(self, card_ids)
	
	local NextPlayerCanUse, NextPlayerisEnemy
	local NextPlayer = self.player:getNextAlive()
	if sgs.turncount > 1 and not self:willSkipPlayPhase(NextPlayer) then
		if self:isFriend(NextPlayer) and sgs.evaluateRoleTrends(NextPlayer) ~= "neutral" then
			NextPlayerCanUse = true
		else
			NextPlayerisEnemy = true
		end
	end	
	for _, enemy in ipairs(self.enemies) do
		if enemy:hasSkill("lihun") and enemy:faceUp() and not NextPlayer:faceUp() and NextPlayer:getHandcardNum() > 4 and NextPlayer:isMale() then
			NextPlayerCanUse = false
		end
	end
	
	local cards = {}
	local trickcard = {}
	for _, card_id in ipairs(card_ids) do
		local acard = sgs.Sanguosha:getCard(card_id)
		table.insert(cards, acard)
		if acard:isKindOf("TrickCard") then
			table.insert(trickcard , acard)
		end
	end	
	
	local nextfriend_num = 0
	local aplayer = self.player:getNextAlive()
	for i =1, self.player:aliveCount() do
		if self:isFriend(aplayer) then
			aplayer = aplayer:getNextAlive()
			nextfriend_num = nextfriend_num + 1
		else
			break
		end
	end
	
	local SelfisCurrent
	if self.room:getCurrent():objectName() == self.player:objectName() then SelfisCurrent = true end
	
---------------
	
	local needbuyi
	for _, friend in ipairs(self.friends) do
		if friend:hasSkill("buyi") and self.player:getHp() == 1 then
			needbuyi = true
		end
	end
	if needbuyi then
		local maxvaluecard, minvaluecard
		local maxvalue, minvalue = -100, 100
		for _, bycard in ipairs(cards) do
			if not bycard:isKindOf("BasicCard") then
				local value = self:getUseValue(bycard)
				if value > maxvalue then 
					maxvalue = value
					maxvaluecard = bycard
				end
				if value < minvalue then 
					minvalue = value
					minvaluecard = bycard 
				end
			end
		end
		if minvaluecard and NextPlayerCanUse then
			return minvaluecard:getEffectiveId()
		end
		if maxvaluecard then
			return maxvaluecard:getEffectiveId()
		end
	end
	
	local friendneedpeach, peach
	local peachnum = 0
	if NextPlayerCanUse then
		if (not self.player:isWounded() and NextPlayer:isWounded()) or
			(self.player:getLostHp() < self:getCardsNum("Peach")) or
			(not SelfisCurrent and self:willSkipPlayPhase() and self.player:getHandcardNum() + 2 > self.player:getMaxCards()) then
			friendneedpeach = true
		end
	end
	for _, card in ipairs(cards) do
		if card:isKindOf("Peach") then
			peach = card:getEffectiveId()
			peachnum = peachnum + 1
		end
	end
	if (not friendneedpeach and peach) or peachnum > 1 then return peach end
	
	local exnihilo, jink, analeptic, nullification
	for _, card in ipairs(cards) do
		if card:isKindOf("ExNihilo") then
			if not NextPlayerCanUse or (not self:willSkipPlayPhase() and (self:hasSkills("jizhi|zhiheng|rende") or not self:hasSkills("jizhi|zhiheng", NextPlayer))) then
				exnihilo = card:getEffectiveId()
			end
		end	
		if card:isKindOf("Jink")  then
			jink = card:getEffectiveId()
		end
		if card:isKindOf("Analeptic") then
			analeptic = card:getEffectiveId()
		end
		if card:isKindOf("Nullification") then
			nullification = card:getEffectiveId()
		end
	end
	
	for _, friend in ipairs(self.friends) do
		if self:willSkipPlayPhase(friend) or self:willSkipDrawPhase(friend) then return nullification end
	end

	if SelfisCurrent then
		if exnihilo then return exnihilo end
		if (jink or analeptic) and (self:getCardsNum("Jink") == 0 or (self:isWeak() and self:getOverflow() == 0)) then
			return jink or analeptic
		end
	else
		local enemy_num = self:playerGetRound(self.player, self.room:getCurrent(), "enemy")
		local InAttackRange = 0
		for _, enemy in ipairs(self.enemies) do
			if enemy:inMyAttackRange(self.player) then
				InAttackRange = InAttackRange + 1
			end
		end
		local possible_attack = math.min(enemy_num, InAttackRange)
		if possible_attack > self:getCardsNum("Jink") and self:getCardsNum("Jink") <= 2 then
			if jink or analeptic or exnihilo then return jink or analeptic or exnihilo end
		else
			if exnihilo then return exnihilo end
		end
	end 
	
	if nullification and (self:getCardsNum("Nullification") < 2 or not NextPlayerCanUse) then 
		return nullification
	end
	
	self:sortByUseValue(cards)
	for _, card in ipairs(cards) do
		for _, skill in sgs.qlist(self.player:getVisibleSkillList()) do
			local callback = sgs.ai_cardneed[skill:objectName()]
			if type(callback) == "function" and callback(self.player, card, self) then
				return card:getEffectiveId()
			end
		end
	end
	
	local eightdiagram, silverlion, vine, renwang, DefHorse, OffHorse
	local weapon, crossbow, halberd, double, qinggang, axe, gudingdao
	for _, card in ipairs(cards) do
		if card:isKindOf("EightDiagram") then eightdiagram = card:getEffectiveId() end
		if card:isKindOf("SilverLion") then silverlion = card:getEffectiveId() end
		if card:isKindOf("Vine") then vine = card:getEffectiveId() end
		if card:isKindOf("RenwangShield") then renwang = card:getEffectiveId() end
		if card:isKindOf("DefensiveHorse") and not self:getSameEquip(card) then DefHorse = card:getEffectiveId() end
		if card:isKindOf("OffensiveHorse") and not self:getSameEquip(card) then OffHorse = card:getEffectiveId() end
		if card:isKindOf("Crossbow") then crossbow = card end
		if card:isKindOf("DoubleSword") then double = card:getEffectiveId() end
		if card:isKindOf("QinggangSword") then qinggang = card:getEffectiveId() end
		if card:isKindOf("Axe") then axe = card:getEffectiveId() end
		if card:isKindOf("GudingBlade") then gudingdao = card:getEffectiveId() end
		if card:isKindOf("Halberd") then halberd = card:getEffectiveId() end
		if card:isKindOf("Weapon") then weapon = card:getEffectiveId() end
	end
	
	if eightdiagram then
		local lord = getLord(self.player)
		if not self:hasSkills("yizhong|bazhen") and self:hasSkills("tiandu|leiji|noszhenlie|gushou|hongyan") and not self:getSameEquip(card) then
			return eightdiagram 
		end
		if NextPlayerisEnemy and self:hasSkills("tiandu|leiji|noszhenlie|gushou|hongyan", NextPlayer) and not self:getSameEquip(card, NextPlayer) then
			return eightdiagram
		end
		if self.role == "loyalist" and self.player:getKingdom()=="wei" and not self.player:hasSkill("bazhen") and
			lord and lord:hasLordSkill("hujia") and (lord:objectName() ~= NextPlayer:objectName() and NextPlayerisEnemy or lord:getArmor()) then
			return eightdiagram
		end
	end
	
	if silverlion then
		local lightning, canRetrial
		for _, aplayer in sgs.qlist(self.room:getOtherPlayers(self.player)) do	
			if aplayer:hasSkill("leiji") and self:isEnemy(aplayer) then
				return silverlion
			end
			if aplayer:containsTrick("lightning") then
				lightning = true
			end
			if self:hasSkills("guicai|guidao", aplayer) and self:isEnemy(aplayer) then
				canRetrial = true
			end
		end
		if lightning and canRetrial then return silverlion end
		if self.player:isChained() then
			for _, friend in ipairs(self.friends) do
				if self:isEquip("Vine", friend) and friend:isChained() then
					return silverlion
				end
			end
		end
		if self.player:isWounded() then return silverlion end
	end
	
	if vine then
		if sgs.ai_armor_value.Vine(self.player, self) > 0 and self.room:alivePlayerCount() <= 3 then
			return vine
		end
	end
	
	if renwang then
		if sgs.ai_armor_value.RenwangShield(self.player, self) > 0 and self:getCardsNum("Jink") == 0 then return renwang end		
	end
	
	if DefHorse and (not self.player:hasSkill("leiji") or self:getCardsNum("Jink") == 0) then
		local before_num, after_num = 0, 0
		for _, enemy in ipairs(self.enemies) do
			if enemy:canSlash(self.player, nil, true) then
				before_num = before_num + 1
			end
			if enemy:canSlash(self.player, nil, true, 1) then
				after_num = after_num + 1
			end
		end
		if before_num > after_num and (self:isWeak() or self:getCardsNum("Jink") == 0) then return DefHorse end
	end
	
	if analeptic then
		local slashs = self:getCards("Slash")
		for _, enemy in ipairs(self.enemies) do
			for _, slash in ipairs(slashs) do
				if (self:getCardsNum("Jink", enemy) < 1 or enemy:isKongcheng()) and self:slashIsEffective(slash, enemy) and self.player:canSlash(enemy, slash) and self:slashIsAvailable() then
					return analeptic
				end
			end
		end
	end
	
	if weapon and (self:getCardsNum("Slash") > 0 and self:slashIsAvailable() or not SelfisCurrent) then
		local current_range = (self.player:getWeapon() and sgs.weapon_range[self.player:getWeapon():getClassName()]) or 1
		local nosuit_slash = sgs.Sanguosha:cloneCard("slash", sgs.Card_NoSuit, 0)
		local slash = SelfisCurrent and self:getCard("Slash") or nosuit_slash
		
		self:sort(self.enemies, "defense")

		if crossbow then
			if #self:getCards("Slash") > 1 or self:hasSkills("kurou|keji") 
				or (self:hasSkills("luoshen|yongsi|luoying|guzheng") and not SelfisCurrent and self.room:alivePlayerCount() >= 4) then
				return crossbow:getEffectiveId()
			end
			if self.player:hasSkill("guixin") and self.room:alivePlayerCount() >= 6 and (self.player:getHp() > 1 or self:getCardsNum("Peach") > 0) then
				return crossbow:getEffectiveId()
			end
			if self.player:hasSkill("rende") then
				for _, friend in ipairs(self.friends_noself) do
					if getCardsNum("Slash", friend) > 1 then
						return crossbow:getEffectiveId()
					end
				end
			end
			if self:isEnemy(NextPlayer) then
				local CanSave, huanggai, zhenji
				for _, enemy in ipairs(self.enemies) do
					if enemy:hasSkill("buyi") then CanSave = true end
					if enemy:hasSkill("jijiu") and getKnownCard(enemy, "red", nil, "he") > 1 then CanSave = true end
					if enemy:hasSkill("chunlao") and enemy:getPile("wine"):length() > 1 then CanSave = true end
					if enemy:hasSkill("kurou") then huanggai = enemy end
					if enemy:hasSkill("keji") then return crossbow:getEffectiveId() end
					if self:hasSkills("luoshen|yongsi|guzheng", enemy) then return crossbow:getEffectiveId() end
					if enemy:hasSkill("luoying") and card:getSuit() ~= sgs.Card_Club then return crossbow:getEffectiveId() end
				end
				if huanggai then
					if huanggai:getHp() > 2 then return crossbow:getEffectiveId() end
					if CanSave then return crossbow:getEffectiveId() end
				end
				if getCardsNum("Slash", NextPlayer) >= 3 and NextPlayerisEnemy then return crossbow:getEffectiveId() end
			end
		end
		
		if halberd then
			if self.player:hasSkill("rende") and #self.friends_noself > 0 then return halberd end
			if SelfisCurrent and self:getCardsNum("Slash") == 1 and self.player:getHandcardNum() == 1 then return halberd end
		end
		
		if gudingdao then
			local range_fix = current_range - 2
			for _, enemy in ipairs(self.enemies) do
				if self.player:canSlash(enemy, slash, true, range_fix) and enemy:isKongcheng() and not enemy:hasSkill("tianming") and
				(not SelfisCurrent or (self:getCardsNum("Dismantlement") > 0 or (self:getCardsNum("Snatch") > 0 and self.player:distanceTo(enemy) == 1))) then
					return gudingdao
				end
			end	
		end		
		
		if axe then
			local range_fix = current_range - 3
			local FFFslash = self:getCard("FireSlash")
			for _, enemy in ipairs(self.enemies) do
				if self:isEquip("Vine", enemy) and FFFslash and self:slashIsEffective(FFFslash, enemy) and 
					self.player:getCardCount(true) >= 3 and self.player:canSlash(enemy, FFFslash, true, range_fix) then
					return axe
				elseif self:getCardsNum("Analeptic") > 0 and self.player:getCardCount(true) >= 4 and
					self:slashIsEffective(slash, enemy) and self.player:canSlash(enemy, slash, true, range_fix) then
					return axe
				end
			end
		end
		
		if double then
			local range_fix = current_range - 2
			for _, enemy in ipairs(self.enemies) do
				if self.player:getGender() ~= enemy:getGender() and self.player:canSlash(enemy, nil, true, range_fix) then
					return double
				end
			end
		end
		
		if qinggang then
			local range_fix = current_range - 2
			for _, enemy in ipairs(self.enemies) do
				if self.player:canSlash(enemy, slash, true, range_fix) and self:slashIsEffective(slash, enemy, true) then
					return qinggang
				end
			end
		end
		
	end
		
	local snatch, dismantlement, indulgence, supplyshortage, collateral, duel, aoe, godsalvation, fireattack
	local new_enemies = {}
	if #self.enemies > 0 then new_enemies = self.enemies
	else
		for _, aplayer in sgs.qlist(self.room:getOtherPlayers(self.player)) do
			if sgs.evaluateRoleTrends(aplayer) == "neutral" then
				table.insert(new_enemies, aplayer)
			end
		end
	end
	for _, card in ipairs(cards) do
		for _, enemy in ipairs(new_enemies) do
			if card:isKindOf("Snatch") and self:hasTrickEffective(card, enemy, self.player) and self.player:distanceTo(enemy) == 1 and not enemy:isNude() then
				snatch = card:getEffectiveId()
			elseif not enemy:isNude() and card:isKindOf("Dismantlement") and self:hasTrickEffective(card, enemy, self.player) then
				dismantlement = card:getEffectiveId()
			elseif card:isKindOf("Indulgence") and self:hasTrickEffective(card, enemy, self.player) and not enemy:containsTrick("indulgence") then
				indulgence = card:getEffectiveId()
			elseif card:isKindOf("SupplyShortage")	and self:hasTrickEffective(card, enemy, self.player) and not enemy:containsTrick("supply_shortage") then
				supplyshortage = card:getEffectiveId()
			elseif card:isKindOf("Collateral") and self:hasTrickEffective(card, enemy, self.player) and enemy:getWeapon() then
				collateral = card:getEffectiveId()
			elseif card:isKindOf("Duel") and self:hasTrickEffective(card, enemy, self.player) and
					(self:getCardsNum("Slash") >= getCardsNum("Slash", enemy) or self.player:getHandcardNum() > 4) then
				duel = card:getEffectiveId()
			elseif card:isKindOf("AOE") then
				local dummy_use = {isDummy = true}
				self:useTrickCard(card, dummy_use)
				if dummy_use.card then
					aoe = card:getEffectiveId() 
				end
			elseif card:isKindOf("FireAttack") and self:hasTrickEffective(card, enemy, self.player) then
				local FFF
				local jinxuandi = self.room:findPlayerBySkillName("wuling")
				if jinxuandi and jinxuandi:getMark("@fire") > 0 then FFF = true end
				if self.player:hasSkill("shaoying") then FFF = true end
				if enemy:getHp() == 1 or self:isEquip("Vine", enemy) or enemy:getMark("@gale") > 0 then FFF = true end
				if FFF then
					local suits= {}
					local suitnum = 0
					for _, hcard in sgs.qlist(self.player:getHandcards()) do
						if hcard:getSuit() == sgs.Card_Spade then
							suits.spade = true
						elseif hcard:getSuit() == sgs.Card_Heart then
							suits.heart = true
						elseif hcard:getSuit() == sgs.Card_Club then
							suits.club = true
						elseif hcard:getSuit() == sgs.Card_Diamond then
							suits.diamond = true
						end
					end
					for k, hassuit in pairs(suits) do
						if hassuit then suitnum = suitnum + 1 end
					end
					if suitnum >=3 or (suitnum >= 2 and enemy:getHandcardNum() == 1 ) then
						fireattack = card:getEffectiveId()
					end
				end
			elseif card:isKindOf("GodSalvation") and self:willUseGodSalvation(card) then
				godsalvation = card:getEffectiveId()
			end
		end
		
		for _, friend in ipairs(self.friends_noself) do
			if (self:hasTrickEffective(card, friend) and (self:willSkipPlayPhase(friend, true) or self:willSkipDrawPhase(friend, true))) or
				self:needToThrowArmor(friend) then
				if isCard("Snatch", card, self.player) and self.player:distanceTo(friend) == 1 then				
					snatch = card:getEffectiveId()
				elseif isCard("Dismantlement", card, self.player) then
					dismantlement = card:getEffectiveId()
				end
			end
		end
	end
	
	if snatch or dismantlement or indulgence or supplyshortage or collateral or duel or aoe or godsalvation or fireattack then 
		if not self:willSkipPlayPhase() or not NextPlayerCanUse then
			return snatch or dismantlement or indulgence or supplyshortage or collateral or duel or aoe or godsalvation or fireattack
		end
		if #trickcard > nextfriend_num + 1 and NextPlayerCanUse then
			return fireattack or godsalvation or aoe or duel or collateral or supplyshortage or indulgence or dismantlement or snatch
		end
	end
	
	if weapon and not self.player:getWeapon() and self:getCardsNum("Slash") > 0 and (self:slashIsAvailable() or not SelfisCurrent) then
		local inAttackRange
		for _, enemy in ipairs(self.enemies) do
			if self.player:inMyAttackRange(enemy) then
				inAttackRange = true
				break
			end
		end
		if not inAttackRange then return weapon end
	end
	
	self:sortByCardNeed(cards, true)
	for _, card in ipairs(cards) do
		if not card:isKindOf("TrickCard") and not card:isKindOf("Peach") then 
			return card:getEffectiveId()
		end
	end
	
	return cards[1]:getEffectiveId()
end



