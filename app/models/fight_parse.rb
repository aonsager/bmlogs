class FightParse < ActiveRecord::Base
  belongs_to :fight
  has_many :cooldown_parses, dependent: :destroy
  after_create :init_vars
  attr_accessor :capped, :serenity

  def init_vars
    @capped = false
    @capped_started_at = 0
    @cooldowns = {
      'guard' => {active: false, cp: nil},
      'eb' => {active: false, cp: nil},
      'zm' => {active: false, cp: nil},
      'dm' => {active: false, cp: nil},
      'dh' => {active: false, cp: nil},
      'fb' => {active: false, cp: nil},
    }

    # @guarding = false
    # @ebing = false
    @serenity = false
    @shuffling = false
    # @zming = false
    # @fbing = false
    # @dhing = false
    # @dming = false

    @total_eb = 0
    @damage_by_source = {}
  end

  # getters

  def fight_date
    return Report.where(report_id: self.fight.report_id).first.started_at.strftime("%-m/%-d")
  end

  def fight_time
    return (self.ended_at - self.started_at) / 1000
  end

  def dps
    return (self.player_damage_done + self.pet_damage_done) / self.fight_time
  end

  def dtps
    return self.damage_taken / self.fight_time
  end

  def shps
    return (self.self_healing + self.self_absorbing) / self.fight_time
  end

  def ehps
    return (self.external_healing + self.external_absorbing) / self.fight_time
  end

  def gps
    return (self.guard_absorbed + self.guard_healed) / self.fight_time
  end

  def ebps
    return self.eb_avoided / self.fight_time
  end

  def calc_guard_total
    total = {absorbed: 0, healed: 0}
    self.cooldown_parses.guard.each do |g|
      total[:absorbed] += g.absorbed_amount
      total[:healed] += g.healed_amount / 1.3
    end
    return total
  end

  def calc_eb_total
    total = 0
    self.cooldown_parses.eb.each do |eb|
      total += eb.reduced_amount
    end
    return total
  end

  # setters

  def cast_kegsmash
    self.kegsmash += 1 
  end

  def cast_tigerpalm
    self.tigerpalm += 1
  end

  def cap(capped, timestamp)
    if @capped != capped
      capped ? @capped_started_at = timestamp : self.capped_time += (timestamp - @capped_started_at) / 1000
    end
    @capped = capped
  end

  def gain_cooldown(type, timestamp)
    @cooldowns[type][:active] = true
    @cooldowns[type][:cp] = CooldownParse.new(fight_parse_id: self.id, cooldown_type: type, started_at: timestamp)
  end

  def drop_cooldown(type, timestamp)
    @cooldowns[type][:cp].ended_at = timestamp
    @cooldowns[type][:cp].save
    @cooldowns[type][:active] = false
  end

  # def gain_guard(timestamp)
  #   @guarding = true
  #   @current_guard = CooldownParse.new(fight_parse_id: self.id, cooldown_type: 'guard', started_at: timestamp)
  # end

  def guard(ability_id, name, amount)
    @cooldowns['guard'][:cp].ability_hash[ability_id] ||= {name: name, amount: 0}
    @cooldowns['guard'][:cp].ability_hash[ability_id][:amount] += amount
    @cooldowns['guard'][:cp].absorbed_amount += amount
    self.self_absorb(amount)
  end

  # def drop_guard(timestamp)
  #   @current_guard.ended_at = timestamp
  #   @current_guard.save
  #   @guarding = false
  # end

  def gain_shuffle(timestamp)
    @shuffling = true
    self.shuffle -= timestamp
  end

  def drop_shuffle(timestamp)
    self.shuffle -= @started_at if !@shuffling # had buff when fight started
    @shuffling = false
    self.shuffle += timestamp
  end

  # def gain_eb(timestamp)
  #   @ebing = true
  #   @current_eb = CooldownParse.new(fight_parse_id: self.id, cooldown_type: 'eb', started_at: timestamp)
  # end

  # def drop_eb(timestamp)
  #   @current_eb.ended_at = timestamp
  #   @current_eb.save
  #   @ebing = false
  # end

  # def gain_zm(timestamp)
  #   @zming = true
  #   @current_zm = CooldownParse.new(fight_parse_id: self.id, cooldown_type: 'zm', started_at: timestamp)
  # end

  # def drop_zm(timestamp)
  #   @current_zm.ended_at = timestamp
  #   @current_zm.save
  #   @zming = false
  # end

  # def gain_dm(timestamp)
  #   @dming = true
  #   @current_dm = CooldownParse.new(fight_parse_id: self.id, cooldown_type: 'dm', started_at: timestamp)
  # end

  # def drop_dm(timestamp)
  #   @current_dm.ended_at = timestamp
  #   @current_dm.save
  #   @dming = false
  # end

  # def gain_dh(timestamp)
  #   @dhing = true
  #   @current_dh = CooldownParse.new(fight_parse_id: self.id, cooldown_type: 'dh', started_at: timestamp)
  # end

  # def drop_dh(timestamp)
  #   @current_dh.ended_at = timestamp
  #   @current_dh.save
  #   @dhing = false
  # end

  def stagger(amount)
    self.damage_to_stagger += amount
  end

  def stagger_tick(amount)
    self.damage_from_stagger += amount
  end

  def deal_damage_player(amount)
    self.player_damage_done += amount
  end

  def deal_damage_pet(amount)
    self.pet_damage_done += amount
  end

  def self_absorb(amount)
    self.self_absorbing += amount
  end

  def self_heal(amount)
    self.self_healing += amount
    @current_guard.healed_amount += amount if @guarding
  end

  def external_absorb(amount)
    self.external_absorbing += amount
  end

  def external_heal(amount)
    self.external_healing += amount
  end

  def record_damage(source_id, ability_id, name, ability_type, amount, absorbed, max_hp)
    source_id ||= -1
    self.damage_taken += amount
    return if (amount + absorbed) == 0

    # work our way back up the mitigation stack to see how much each ability mitigated
    if @cooldowns['zm'][:active]
      @cooldowns['zm'][:cp].ability_hash[ability_id] ||= {name: name, dmg_taken: 0}
      @cooldowns['zm'][:cp].ability_hash[ability_id][:dmg_taken] += (amount + absorbed)
      @cooldowns['zm'][:cp].reduced_amount += (amount + absorbed) * 9 # 90% reduction
      amount += @cooldowns['zm'][:cp].reduced_amount
    end
    if @cooldowns['fb'][:active]
      @cooldowns['fb'][:cp].ability_hash[ability_id] ||= {name: name, dmg_taken: 0}
      @cooldowns['fb'][:cp].ability_hash[ability_id][:dmg_taken] += (amount + absorbed)
      @cooldowns['fb'][:cp].reduced_amount += (amount + absorbed) / 4 # 20% reduction
      amount += @cooldowns['dh'][:cp].reduced_amount
    end
    if @cooldowns['dm'][:active] && ability_type != 1 # record magic damage reduced by DM
      @cooldowns['dm'][:cp].ability_hash[ability_id] ||= {name: name, dmg_taken: 0}
      @cooldowns['dm'][:cp].ability_hash[ability_id][:dmg_taken] += (amount + absorbed)
      @cooldowns['dm'][:cp].reduced_amount += (amount + absorbed) * 9 # 90% reduction
      amount += @cooldowns['dm'][:cp].reduced_amount
    end
    if @cooldowns['dh'][:active] && amount >= amount * 0.15
      @cooldowns['dh'][:cp].ability_hash[ability_id] ||= {name: name, dmg_taken: 0}
      @cooldowns['dh'][:cp].ability_hash[ability_id][:dmg_taken] += (amount + absorbed)
      @cooldowns['dh'][:cp].reduced_amount += (amount + absorbed) # 50% reduction
      amount += @cooldowns['dh'][:cp].reduced_amount
    end

    # record the attack's initial damage
    @damage_by_source[source_id] ||= {}
    ability = @damage_by_source[source_id][ability_id] ||= {name: name, count: 0, total: 0}
    ability[:total] += amount + absorbed
    ability[:count] += 1
    
  end

  def dodge(source_id, ability_id, ability_name)
    return unless @cooldowns['eb'][:active]
    source ||= -1
    @cooldowns['eb'][:cp].ability_hash[source_id] ||= {name: 'Source Name', abilities: {}}
    @cooldowns['eb'][:cp].ability_hash[source_id][:abilities][ability_id] ||= {name: ability_name, dodged: 0, avg: 0}
    @cooldowns['eb'][:cp].ability_hash[source_id][:abilities][ability_id][:dodged] += 1
  end

  def clean
    # end cooldowns
    self.drop_shuffle(self.ended_at) if @shuffling
    self.drop_guard(self.ended_at) if @guarding
    self.drop_eb(self.ended_at) if @ebing

    # calculate total damage avoided with Eb
    self.cooldown_parses.eb.each do |eb|
      eb.reduced_amount = 0
      eb.ability_hash.each do |source_id, source|
        source[:abilities].each do |ability_id, ability|
          ability[:avg] = @damage_by_source[source_id][ability_id][:total] / @damage_by_source[source_id][ability_id][:count]
          avoided_dmg = ability[:dodged] * ability[:avg]
          eb.reduced_amount += avoided_dmg
        end
      end
      eb.save
    end

    self.guard_absorbed = self.calc_guard_total[:absorbed]
    self.guard_healed = self.calc_guard_total[:healed]
    self.eb_avoided = self.calc_eb_total
    self.fight.status = :done
    self.fight.save
  end

  def print
    puts "Kegsmash: #{self.kegsmash}/#{fight_time/8} (#{100*self.kegsmash/(fight_time/8)}%)"
    puts "Tigerpalm: #{self.tigerpalm}"
    puts "Shuffle uptime: #{self.shuffle / (10 * fight_time)}%"
    puts "Time spent energy capped: #{self.capped_time} seconds"
    puts "Percent Stagger Purified: #{100 * (self.damage_to_stagger - self.damage_from_stagger) / self.damage_to_stagger}% (#{self.damage_from_stagger} damage taken)"
    puts "Total damage: #{self.player_damage_done} Player, #{self.pet_damage_done} Pet (#{(self.player_damage_done + self.pet_damage_done) / fight_time} DPS)"
    puts "Damage taken: #{self.damage_taken} (#{self.damage_taken / fight_time} DTPS)"
    puts "Self healing: #{self.self_healing} Healed, #{self.self_absorbing} Absorbed"
    puts "Self healing per second: #{(self.self_healing + self.self_absorbing) / fight_time}"
    puts "External healing: #{self.external_healing} Healed, #{self.external_absorbing} Absorbed"
    puts "External healing per second: #{(self.external_healing + self.external_absorbing) / fight_time}"
    puts ""
    puts "Total Guard: #{GuardParse.total_guard(self.id)} (#{GuardParse.total_guard(self.id) / fight_time} HPS)"
    puts ""
    puts "Total Damage avoided through Elusive Brew: #{@total_eb} (#{@total_eb / fight_time} HPS)"
    puts ""
  end

end