#!/usr/bin/env ruby

# go through and convert things to ternary
# catch when user bets too much, non-integer, or runs out of cash
# A needs to be either value
# push doesn't score correctly

INIT_CASH = 1000

CARD_SUITS = %w(Hearts Diamonds Spades Clubs)

CARD_RANKS = %w(Ace 2 3 4 5 6 7 8 9 10 Jack Queen King)

CARD_VALUES = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 10, 10, 10]

def prompt(*args)
  print(*args)
  gets.chomp
end

def bool_prompt(message)
  action = prompt(message)
  while action != "y" && action != "n"
    action = prompt("Invalid response. Please type \"y\" or \"n\".")
  end
  action == "n" ? false : true
end

class Game
  attr_accessor :players, :live, :shoe, :cards

  def initialize()
    @live = true

    # needs to ensure that input is number
    num_players = prompt("How many players are at the table?\n").to_i
    while num_players <= 0
      num_players = prompt("Please enter a valid integer greater than 0.\n").to_i
    end
    
    # this should save time instead of calculating the length of the players list, right?
    @players = []
    num_players.times do |count|
      name = prompt("Player #{count + 1} name:")
      @players.push(Player.new(name))
    end

    # dealer will be the last to play each round; his "cash" will represent the casino's winnings
    # dealer's bet is set to 1 for error checking later, should fix?
    @players.push(Player.new("Dealer", true, 1))

    # is there an ideal number of decks per person playing?
    num_decks = 1

    @cards = []
    num_decks.times do
      CARD_SUITS.each do |suit|
        CARD_RANKS.each_with_index do |rank, i|
          @cards.push(Card.new(suit, rank, CARD_VALUES[i]))
        end
      end
    end
  end

  def shuffle
    @cards = @cards.shuffle
  end

  def live_players
    @players.select {|player| player.live}
  end

  def deal_cards
      live_players.each do |player|
        # could be prettier
        player.bet = player.dealer ? 0 : prompt("#{player.name}: You currently have $#{player.cash}. What would you like to bet?").to_i
        while player.bet < 1 || player.bet > player.cash
          player.bet = player.dealer ? 1 : prompt("#{player.name}: Please enter a valid bet from $0 to $#{player.cash}").to_i
        end
        2.times do |count|
          # this breaks if there are no cards
          new_card = @cards.pop
          player.hand.push(new_card)
          if player.dealer && count == 0
            new_card.visible = false
          end
          puts "#{player.name} was dealt the #{new_card.name}."
        end
        if player.hand_sum == 21
          puts "Blackjack!"
          # if player is dealer, end game
        end
        puts "\n"
      end

  end

  def new_round
    live_players.each do |player|
      @cards += player.hand
      player.hand = []
      player.bet = nil
      player.won = nil
    end
    shuffle
  end

  def play_round
    live_players.each do |player|
      if player.hand_sum == 21
        puts "#{player.name} has blackjack.\n"
      else
        action = player.get_action
        while action != "s"
          if action == "h"
            new_card = @cards.pop
            player.hand.push(new_card)
            puts "#{player.name} drew the #{new_card.name}."
            if player.hand_sum > 21
              puts "Bust!"
              break
            elsif player.hand_sum == 21
              puts "21!"
              break
            else
              action = player.get_action
            end
          elsif action != "s"
            action = prompt("Invalid response. Please type \"h\" to hit or \"s\" to stand.")
          end
        end
      end
    end
  end

  def score_round
    # what about when dealer gets 21? need to account for some extra rules here
    dealer_score = live_players.last.hand_sum
    if dealer_score <= 21
      live_players[0..-2].each do |player|
        if player.hand_sum <= 21
          if player.hand_sum > dealer_score
            player.won = true
          elsif player.hand_sum == dealer_score
            player.won = nil
          else
            player.won = false
          end
        else
          # player busted
          player.won = false
        end
      end
    else
      # dealer busted
      live_players[0..-2].each do |player|
        if player.hand_sum <= 21
          player.won = true
        else
          player.won = false
        end
      end
    end
  end

  # collect bets iteratively at end
  def collect_winnings
    dealer = @players.last
    live_players[0..-2].each do |player|
      # don't think this works
      if player.won.nil?
        puts "#{player.name}: Push. Dealer has returned your bet. You have $#{player.cash}."
      elsif player.won
        player.cash += player.bet
        dealer.cash -= player.bet
        puts "#{player.name}: You win $#{player.bet}! You now have $#{player.cash}."
      else
        player.cash -= player.bet
        dealer.cash += player.bet
        if player.cash <= 0
          player.live = false
          puts "#{player.name}: You've lost all of your money! Better luck next time."
        else
          puts "#{player.name}: You lose #{player.bet}. You have $#{player.cash} remaining."
        end
      end
    end
  end

end

class Player
  attr_accessor :bet, :cash, :hand, :live, :won
  attr_reader :name, :dealer

  def initialize(name, dealer = false, cash = INIT_CASH, won = nil)
    @name = name
    @dealer = dealer
    @cash = cash
    @hand = []
    @won = won
    @bet = 0
    @live = true
  end

  def hand_sum
    @hand.map {|card| card.value}.reduce(:+)
  end

  def show_hand
    puts "#{@name}'s hand:\n"
    @hand.each do |card|
      card.visible = true
      puts "#{card.name}\n"
    end
  end

  def get_action
    show_hand
    if @dealer
      if hand_sum < 17
        action = "h"
        puts "The dealer has #{hand_sum} points and must hit."
      else
        action = "s"
        puts "The dealer has #{hand_sum} points and must stand."
      end
      sleep(1)
    else
      action = prompt("#{@name}\'s turn: You currently have #{hand_sum} points. What would you like to do?")
    end
    return action
  end
end

class Card
  attr_accessor :visible
  attr_reader :suit, :rank, :value

  def initialize(suit, rank, value, visible = true)
    @suit = suit
    @rank = rank
    @value = value
    @visible = visible
  end

  def name
    if @visible
      "#{@rank} of #{@suit}"
    else
      "hole card"
    end
  end

end

if __FILE__ == $0
  program_live = true

  while program_live
    game = Game.new

    game_live = true

    while game_live
      game.new_round
      game.deal_cards
      game.play_round
      game.score_round
      game.collect_winnings
      
      game_live = bool_prompt("Round over. Deal again?")

      if !game_live
        program_live = bool_prompt("New game?")
      end

      if !program_live
        break;
      end
    end
  end
  puts "Thanks for playing!"
end