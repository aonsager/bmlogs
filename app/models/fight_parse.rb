class FightParse < ActiveRecord::Base
  belongs_to :fight
  has_many :guard_parse, dependent: :destroy
  has_many :eb_parse, dependent: :destroy
  after_initialize :init_vars
  attr_accessor :ebing, :capped, :serenity

  def init_vars
    @capped = false
    @capped_started_at = 0

    @serenity = false
    @shuffling = false

    @guarding = false
    GuardParse.where(fight_parse_id: self.id).destroy_all
    @current_guard = GuardParse.new(fight_parse_id: self.id, started_at: started_at)

    @ebing = false
    EbParse.where(fight_parse_id: self.id).destroy_all
    @current_eb = EbParse.new(fight_parse_id: self.id, started_at: started_at)
    @dodge = {}
    # {sources: {}, started_at: started_at, ended_at: started_at}
    @total_eb = 0

    @damage_by_source = {}
  end

  def fight_time
    return (self.ended_at - self.started_at) / 1000
  end

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
    if @ebing # if fight started with elusive brew up, ignore for averages
      @current_eb.save 
      @dodge.each do |source_id, source|
        source[:abilities].each do |ability_id, ability|
          next unless @damage_by_source[source_id].has_key?(ability_id)

          EbSource.create(eb_parse_id: @current_eb.id, source_id: source_id, source_name: source[:name], ability_id: ability_id, ability_name: ability[:name], dodged_count: ability[:dodged], average_dmg: @damage_by_source[source_id][ability_id][:avg])
        end
      end
    end
    # @ebs << @current_eb if @ebing # if fight started with elusive brew up, ignore for averages
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

  def record_damage(source, guid, name, amount, absorbed)
    @damage_by_source[source] ||= {}
    ability = @damage_by_source[source][guid] ||= {name: name, avg: 0.0, count: 0}
    ability[:avg] = ability[:avg] * ability[:count] / (ability[:count] + 1) + (amount + absorbed) * 1 / (ability[:count] + 1)
    ability[:count] += 1
  end

  def dodge(source_id, ability_id, ability_name)
    # source = EbSource.where(eb_parse_id: @current_eb.id, source_id: source_id, ability_id: ability_id).first_or_initialize
    # source.ability_name = ability_name
    # source.dodged += 1
    @dodge[source_id] ||= {name: 'Source Name', abilities: {}}
    @dodge[source_id][:abilities][ability_id] ||= {name: ability_name, dodged: 0}
    @dodge[source_id][:abilities][ability_id][:dodged] += 1
  end

  def clean
    # end shuffle if fight ended with shuffle still up
    self.shuffle += self.ended_at if @shuffling

    # calculate total damage healed/absorbed with guard
    GuardParse.where(fight_parse_id: self.id).each do |g|
      guarded = g.absorbed + (g.healed/1.3).to_i
      puts "Guard #{g.started_at/1000}-#{g.ended_at/1000}: Absorbed #{g.absorbed}, Healed #{g.healed} (#{guarded})"
    end

    # calculate total damage avoided with Eb
    

    EbParse.where(fight_parse_id: self.id).each do |eb|
      puts "Elusive Brew #{eb.started_at/1000}-#{eb.ended_at/1000}:"
      eb_dmg = 0
      EbSource.where(eb_parse_id: eb.id).each do |source|
        eb_dmg += source.avoided_dmg
        puts "#{source.ability_name}: dodged #{source.dodged_count} (#{source.avoided_dmg})"
      end
      puts "Total Avoided Damage: #{eb_dmg}"
      @total_eb += eb_dmg
      puts ""
    end
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