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
    @cooldown_buffer = {
      'guard' => 0,
      'eb' => 0,
      'zm' => 0,
      'dm' => 0,
      'dh' => 0,
      'fb' => 0,
    }
    @absorbs = {
      :self_absorb => 0,
      :external_absorb => 0
    }
    @hp_parses = {
      :hp => {},
      :self_heal => {},
      :external_heal => {},
      :self_absorb => {},
      :external_absorb => {},
    }
    @serenity = false
    @shuffling = false
    @last_hp = 0
    @total_eb = 0
    @damage_by_source = {}
    @default_max_hp = 0
    self.shuffle = 0
  end

  # getters

  def fight_date
    return self.report_started_at.nil? ? "N/A" : self.report_started_at.strftime("%-m/%-d")
  end

  def fight_time
    return (self.ended_at - self.started_at) / 1000 rescue 0
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
    drop_cooldown(type, timestamp, true) if @cooldowns[type][:active]
    @cooldowns[type][:active] = true
    @cooldowns[type][:cp] = CooldownParse.new(fight_parse_id: self.id, cooldown_type: type, started_at: timestamp)
    @cooldowns[type][:attacks] = [] if type == 'dh' # to record damage and negate stagger
  end

  def drop_cooldown(type, timestamp, force = false)
    return if @cooldowns[type][:cp].nil?
    if force
      @cooldown_buffer[type] = timestamp
    else
      if @cooldown_buffer[type] == 0 # allow for a buffer time, in case a buff is dropped before damage is recorded
        @cooldown_buffer[type] = timestamp
        return
      elsif (@cooldown_buffer[type] - timestamp).abs <= 30 # 30ms is probably enough of a buffer
        return  # don't drop the cooldown yet, because we're still in the buffer time
      end
    end
    # buffer time has expired
    calculate_dh if type == 'dh' # figure out which attacks may have triggered DH
    @cooldowns[type][:cp].ended_at = @cooldown_buffer[type]
    @cooldowns[type][:cp].save
    @cooldowns[type][:active] = false
    @cooldown_buffer[type] = 0
  end

  def gain_absorb(guid, amount, type, hitPoints, timestamp) # type is :self_absorb or :external_absorb
    @absorbs[type] += amount - @absorbs[guid].to_i # if the shield was refreshed, just add the difference
    @absorbs[guid] = amount # refresh the shield size
    time = (timestamp - self.started_at)
    @hp_parses[type][time] = @absorbs[type]
    self.record_hp(hitPoints, timestamp)
  end

  def drop_absorb(guid, amount, type, hitPoints, timestamp) # type is :self_absorb or :external_absorb
    @absorbs[guid] = 0
    @absorbs[type] -= amount
    time = (timestamp - self.started_at)
    @hp_parses[type][time]= @absorbs[type]
    self.record_hp(hitPoints, timestamp)
  end

  def calculate_dh
    @cooldowns['dh'][:cp].ability_hash = {}
    @cooldowns['dh'][:attacks].reject! {|attack| attack[:ability_id] == 0}
    # fill missing max_hp values, because it's not saved if the attack is fully absorbed(?)
    @cooldowns['dh'][:attacks].each {|attack| attack[:max_hp] = @default_max_hp if attack[:max_hp].nil? }
    # sort by damage % of max hp
    @cooldowns['dh'][:attacks].sort! {|a, b| (b[:amount] - b[:staggered]).to_f / b[:max_hp] <=> (a[:amount] - a[:staggered]).to_f / a[:max_hp]}
    # grab the highest 3 attacks and see if they may have triggered DH
    0.upto(2){ |i|
      a = @cooldowns['dh'][:attacks][i]
      break if a.nil?
      percent = (a[:amount] - a[:staggered]).to_f / a[:max_hp]
      if percent >= 0.075 # might have reduced
        @cooldowns['dh'][:cp].ability_hash[i] = {ability_id: a[:ability_id], name: a[:name], amount: a[:amount] - a[:staggered], staggered: a[:staggered], percent: percent, sure: 'maybe', max_hp: a[:max_hp]}
        if percent >= 0.15 || @cooldown_buffer['dh'] - @cooldowns['dh'][:cp].started_at < 45000 # definitely was reduced
          @cooldowns['dh'][:cp].ability_hash[i][:sure] = 'yes'
        end 
        @cooldowns['dh'][:cp].reduced_amount += (a[:amount] - a[:staggered])
      end
    }
  end

  def guard(ability_id, name, amount, hitPoints, timestamp)
    gain_cooldown('guard', timestamp) if !@cooldowns['guard'][:active]
    @cooldowns['guard'][:cp].ability_hash[ability_id] ||= {name: name, casts: 0, amount: 0}
    @cooldowns['guard'][:cp].ability_hash[ability_id][:amount] += amount
    @cooldowns['guard'][:cp].ability_hash[ability_id][:casts] += 1
    @cooldowns['guard'][:cp].absorbed_amount += amount
    self.self_absorb(115295, amount, hitPoints, timestamp)
  end

  def gain_shuffle(timestamp)
    @shuffling = true
    self.shuffle -= timestamp
  end

  def drop_shuffle(timestamp)
    self.shuffle -= self.started_at if !@shuffling # had buff when fight started
    @shuffling = false
    self.shuffle += timestamp
  end

  def stagger(timestamp, amount, ability_id)
    self.damage_to_stagger += amount
    if @cooldowns['dh'][:active] # negate stagger from our recorded damage of this attack
      if !@cooldowns['dh'][:attacks].last.nil? && (@cooldowns['dh'][:attacks].last[:timestamp] - timestamp).abs <= 50 && @cooldowns['dh'][:attacks].last[:ability_id] == ability_id && @cooldowns['dh'][:attacks].last[:staggered] == 0
        @cooldowns['dh'][:attacks].last[:staggered] = amount
      else
        @cooldowns['dh'][:attacks] << {timestamp: timestamp, ability_id: ability_id, name: '', amount: 0, staggered: amount, max_hp: nil}
      end
    end
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

  def self_absorb(guid, amount, hitPoints, timestamp)
    self.self_absorbing += amount
    if @absorbs.has_key?(guid) # if this isn't here, we never recorded the application of the shield
      @absorbs[guid] -= amount
      @absorbs[:self_absorb] -= amount # to balance adding it earlier
    end    
    time = (timestamp - self.started_at)
    @hp_parses[:self_absorb][time] = @absorbs[:self_absorb]
    self.record_hp(hitPoints, timestamp)
  end

  def self_heal(amount, hitPoints, timestamp)
    self.self_healing += amount
    @cooldowns['guard'][:cp].healed_amount += amount if @cooldowns['guard'][:active]
    time = (timestamp - self.started_at)
    @hp_parses[:self_heal][time] ||= 0
    @hp_parses[:self_heal][time] += amount
    self.record_hp(hitPoints, timestamp)
  end

  def external_absorb(guid, amount, hitPoints, timestamp)
    self.external_absorbing += amount
    if @absorbs.has_key?(guid) # if this isn't here, we never recorded the application of the shield
      @absorbs[guid] -= amount
      @absorbs[:external_absorb] -= amount # to balance adding it earlier
    end    
    time = (timestamp - self.started_at)
    @hp_parses[:external_absorb][time] = @absorbs[:external_absorb]
    self.record_hp(hitPoints, timestamp)
  end

  def external_heal(amount, hitPoints, timestamp)
    self.external_healing += amount
    time = (timestamp - self.started_at)
    @hp_parses[:external_heal][time] ||= 0
    @hp_parses[:external_heal][time] += amount
    self.record_hp(hitPoints, timestamp)
  end

  def record_hp(hitPoints, timestamp)
    hitPoints ||= @last_hp
    @last_hp = hitPoints
    time = (timestamp - self.started_at)
    @hp_parses[:hp][time] = hitPoints
  end

  def record_damage(timestamp, source_id, source_friendly, ability_id, name, ability_type, amount, absorbed, max_hp, tick)
    source_id ||= -1
    self.damage_taken += amount
    return if (amount + absorbed) == 0
    return if ability_id == 124255 # ignore damage from stagger
    return if source_friendly
    @default_max_hp = max_hp if !max_hp.nil? && @default_max_hp == 0

    # check if cooldowns need to drop
    @cooldown_buffer.each do |type, buffer|
      drop_cooldown(type, timestamp) if buffer != 0
    end

    # work our way back up the mitigation stack to see how much each ability mitigated
    if @cooldowns['zm'][:active]
      @cooldowns['zm'][:cp].ability_hash[ability_id] ||= {name: name, casts: 0, amount: 0}
      @cooldowns['zm'][:cp].ability_hash[ability_id][:amount] += (amount + absorbed) * 9
      @cooldowns['zm'][:cp].ability_hash[ability_id][:casts] += 1
      @cooldowns['zm'][:cp].reduced_amount += (amount + absorbed) * 9 # 90% reduction
      amount += @cooldowns['zm'][:cp].reduced_amount
    end
    if @cooldowns['fb'][:active]
      @cooldowns['fb'][:cp].ability_hash[ability_id] ||= {name: name, casts: 0, amount: 0}
      @cooldowns['fb'][:cp].ability_hash[ability_id][:amount] += (amount + absorbed) * 1 / 4
      @cooldowns['fb'][:cp].ability_hash[ability_id][:casts] += 1
      @cooldowns['fb'][:cp].reduced_amount += (amount + absorbed) * 1 / 4 # 20% mitigation, ignoring stagger
      amount += @cooldowns['fb'][:cp].reduced_amount
    end
    if @cooldowns['dm'][:active] && ability_type != 1 # record magic damage reduced by DM
      @cooldowns['dm'][:cp].ability_hash[ability_id] ||= {name: name, casts: 0, amount: 0}
      @cooldowns['dm'][:cp].ability_hash[ability_id][:amount] += (amount + absorbed) * 9
      @cooldowns['dm'][:cp].ability_hash[ability_id][:casts] += 1
      @cooldowns['dm'][:cp].reduced_amount += (amount + absorbed) * 9 # 90% reduction
      amount += @cooldowns['dm'][:cp].reduced_amount
    end
    if @cooldowns['dh'][:active] && !tick # ignore ticks for DH
      if !@cooldowns['dh'][:attacks].last.nil? && (@cooldowns['dh'][:attacks].last[:timestamp] - timestamp).abs <= 50 && @cooldowns['dh'][:attacks].last[:ability_id] == ability_id && @cooldowns['dh'][:attacks].last[:staggered] > 0
        @cooldowns['dh'][:attacks].last[:name] = name
        @cooldowns['dh'][:attacks].last[:amount] = amount + absorbed
        @cooldowns['dh'][:attacks].last[:max_hp] = max_hp
      else
        @cooldowns['dh'][:attacks] << {timestamp: timestamp, ability_id: ability_id, name: name, amount: (amount + absorbed), staggered: 0, max_hp: max_hp}
      end
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
    @cooldowns.each do |type, hash|
      drop_cooldown(type, self.ended_at, true) if hash[:active]
    end

    # calculate total damage avoided with Eb
    self.cooldown_parses.eb.each do |eb|
      eb.reduced_amount = 0
      eb.ability_hash.each do |source_id, source|
        source[:abilities].each do |ability_id, ability|
          if @damage_by_source.has_key?(source_id) && @damage_by_source[source_id].has_key?(ability_id)
            ability[:avg] = @damage_by_source[source_id][ability_id][:total] / @damage_by_source[source_id][ability_id][:count]
          else
            ability[:avg] = 0 #TODO get data from other parses?
          end
          avoided_dmg = ability[:dodged] * ability[:avg]
          eb.reduced_amount += avoided_dmg
        end
      end
      eb.save
    end

    @hp_parses.each do |key, hash|
      next if key == :hp
      prev = [0, 0]
      @hp_parses[:hp].each do |time, value|
        if hash.has_key?(time)
          prev = [time, hash[time]]
        else
          if key == :self_heal || key == :external_heal
            if time - prev[0] < 1000 # make the spikes easier to see in the graph
              hash[time] = prev[1]
            else
              hash[time] = 0
            end
          else
            hash[time] = prev[1]
          end
        end
      end
    end

    @hp_parses.each {|key, value| @hp_parses[key] = value.sort_by{|time, value| time} }
    # File.write(Rails.root.join('tmp', "#{self.fight_hash}_#{self.player_id}_hp.json"), @hp_parses.to_json)
    S3_BUCKET.object("#{self.fight_hash}_#{self.player_id}_hp.json").put(body: @hp_parses.to_json)

    self.guard_absorbed = self.calc_guard_total[:absorbed]
    self.guard_healed = self.calc_guard_total[:healed]
    self.eb_avoided = self.calc_eb_total
    self.dh_reduced = self.cooldown_parses.dh.sum(:reduced_amount)
    self.dm_reduced = self.cooldown_parses.dm.sum(:reduced_amount)
    self.zm_reduced = self.cooldown_parses.zm.sum(:reduced_amount)
    self.fb_reduced = self.cooldown_parses.fb.sum(:reduced_amount)

  end

end