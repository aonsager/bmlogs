class FightParse < ActiveRecord::Base
  belongs_to :fight
  has_many :guard_parses, dependent: :destroy
  has_many :eb_parses, dependent: :destroy
  has_many :eb_sources, dependent: :destroy
  after_create :init_vars
  attr_accessor :ebing, :capped, :serenity

  def init_vars
    self.kegsmash = 0
    self.tigerpalm = 0
    self.shuffle = 0
    self.capped_time = 0
    self.damage_to_stagger = 0
    self.damage_from_stagger = 0
    self.player_damage_done = 0
    self.pet_damage_done = 0
    self.damage_taken = 0
    self.self_healing = 0
    self.self_absorbing = 0
    self.external_healing = 0
    self.external_absorbing = 0
    self.save

    @capped = false
    @capped_started_at = 0

    @serenity = false
    @shuffling = false
    @zming = false
    @fbing = false
    @dhing = false
    @dming = false

    @guarding = false
    self.guard_parses.destroy
    @current_guard = GuardParse.new(fight_parse_id: self.id, started_at: started_at)

    @ebing = false
    self.eb_parses.destroy
    @current_eb = EbParse.new(fight_parse_id: self.id, started_at: started_at)
    # @dodge = {}
    # {sources: {}, started_at: started_at, ended_at: started_at}
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
    self.guard_parses.each do |g|
      total[:absorbed] += g.absorbed
      total[:healed] += g.healed / 1.3
    end
    return total
  end

  def calc_eb_total
    total = 0
    self.eb_parses.each do |eb|
      total += eb.total_avoided
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

  def gain_guard(timestamp)
    @guarding = true
    @current_guard = GuardParse.new(fight_parse_id: self.id, started_at: timestamp)
  end

  def guard(amount)
    @current_guard.absorbed += amount
    self_absorb(amount)
  end

  def drop_guard(timestamp)
    @current_guard.ended_at = timestamp
    @current_guard.save if @guarding # if fight started with guard up, ignore for averages
    @guarding = false
  end

  def gain_shuffle(timestamp)
    @shuffling = true
    self.shuffle -= timestamp
  end

  def drop_shuffle(timestamp)
    self.shuffle -= @started_at if !@shuffling # had buff when fight started
    @shuffling = false
    self.shuffle += timestamp
  end

  def gain_eb(timestamp)
    @ebing = true
    @current_eb = EbParse.new(fight_parse_id: self.id, started_at: timestamp)
  end

  def drop_eb(timestamp)
    @current_eb.ended_at = timestamp
    @current_eb.save if @ebing # if fight started with elusive brew up, ignore for averages
    @ebing = false
  end

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

  def take_damage(amount)
    self.damage_taken += amount
  end

  def self_absorb(amount)
    self.self_absorbing += amount
  end

  def self_heal(amount)
    self.self_healing += amount
    @current_guard.healed += amount if @guarding
  end

  def external_absorb(amount)
    self.external_absorbing += amount
  end

  def external_heal(amount)
    self.external_healing += amount
  end

  def record_damage(source_id, guid, name, amount, absorbed)
    source_id ||= -1
    @damage_by_source[source_id] ||= {}
    ability = @damage_by_source[source_id][guid] ||= {name: name, avg: 0.0, count: 0}
    ability[:avg] = ability[:avg] * ability[:count] / (ability[:count] + 1) + (amount + absorbed) * 1 / (ability[:count] + 1)
    ability[:count] += 1
    if @guarding
      @current_guard.damage_hash[guid] ||= {name: name, amount: 0}
      @current_guard.damage_hash[guid][:amount] += (amount + absorbed)
    end
  end

  def dodge(source_id, ability_id, ability_name)
    source ||= -1
    @current_eb.dodged_hash[source_id] ||= {name: 'Source Name', abilities: {}}
    @current_eb.dodged_hash[source_id][:abilities][ability_id] ||= {name: ability_name, dodged: 0}
    @current_eb.dodged_hash[source_id][:abilities][ability_id][:dodged] += 1
  end

  def clean
    # end shuffle if fight ended with shuffle still up
    self.shuffle += self.ended_at if @shuffling

    # calculate total damage healed/absorbed with guard
    self.guard_parses.each do |g|
      guarded = g.absorbed + (g.healed/1.3).to_i
    end

    # save average damage by ability
    @damage_by_source.each do |source_id, abilities|
      abilities.each do |ability_id, ability|
        EbSource.create(fight_parse_id: self.id, source_id: source_id, ability_id: ability_id, ability_name: ability[:name], average_dmg: ability[:avg])
      end
    end

    # calculate total damage avoided with Eb
    self.eb_parses.each do |eb|
      eb.total_avoided = 0
      eb.dodged_hash.each do |source_id, source|
        source[:abilities].each do |ability_id, ability|
          avoided_dmg = ability[:dodged] * self.eb_sources.where(source_id: source_id, ability_id: ability_id).first.average_dmg
          eb.total_avoided += avoided_dmg
        end
      end
      eb.save
    end

    self.guard_absorbed = self.calc_guard_total[:absorbed]
    self.guard_healed = self.calc_guard_total[:healed]
    self.eb_avoided = self.calc_eb_total
    self.fight.processed = true
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