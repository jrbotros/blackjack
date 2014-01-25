#!/usr/bin/env ruby

# go through and convert things to ternary

INIT_CASH = 1000

CARD_SUITS = %w(Hearts Diamonds Spades Clubs)

CARD_RANKS = %w(Ace 2 3 4 5 6 7 8 9 10 Jack Queen King)

CARD_VALUES = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 10, 10, 10]

def prompt(*args)
  print(*args)
  gets.chomp
end

class Game
  attr_accessor :players, :live, :shoe, :cards

  def initialize()
    @live = true

    # needs to ensure that input is number
    num_players = prompt("How many players are at the table?\n").to_i
    
    # this should save time instead of calculating the length of the players list, right?
    @players = []
    num_players.times do |count|
      name = prompt("Player #{count + 1} name:")
      @players.push(Player.new(name))
    end

    # dealer will be the last to play each round; his "cash" will represent the casino's winnings
    @players.push(Player.new("Dealer", true, 0))

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

  def deal_card
    # this breaks if there are no cards
    @cards.pop
  end

  def new_round
    @players.each do |player|
      @cards += player.hand
      player.hand = []
      player.bet = 0
      player.won = nil
    end
    shuffle
  end

  def score_round
    # what about when dealer gets 21? need to account for some extra rules here
    dealer_score = @players.last.hand_sum
    if dealer_score < 21
      @players[0..-2].each do |player|
        if player.hand_sum < 21
          if player.hand_sum > dealer_score
            player.won = true
          # elsif there is a push, player.won = nil
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
      @players[0..-2].each do |player|
        if player.hand_sum < 21
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
    @players[0..-2].each do |player|
      if player.won.nil?
        puts "#{player.name}: Push. Dealer has returned your bet. You have $#{player.cash}."
      elsif player.won
        player.cash += player.bet
        dealer.cash -= player.bet
        puts "#{player.name}: You win $#{player.bet}! You now have $#{player.cash}."
      else
        player.cash -= player.bet
        dealer.cash += player.bet
        puts "#{player.name}: You lose #{player.bet}. You have $#{player.cash} remaining."
      end
    end
  end

end

class Player
  attr_accessor :bet, :cash, :hand, :won
  attr_reader :name, :dealer

  def initialize(name, dealer = false, cash = INIT_CASH, won = nil)
    @name = name
    @dealer = dealer
    @cash = cash
    @hand = []
    @won = won
    @bet = 0
  end

  def hand_sum
    return @hand.map {|card| card.value}.reduce(:+)
  end

  def show_hand
    puts "#{@name}'s hand:\n"
    @hand.each do |card|
      card.visible = true
      puts card.name + "\n"
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
  game_live = true

  # need to clean up loops
  while true
    puts "#{game_live}"
    if game_live
      game = Game.new
    else
      break
    end
    while true
      if !game_live
        break
      end
      game.new_round
      game.players.each do |player|
        # need error checking here
        player.bet = player.dealer ? 0 : prompt("#{player.name}: You currently have $#{player.cash}. What would you like to bet?").to_i
        2.times do |count|
          new_card = game.deal_card
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

      game.players.each do |player|
        if player.hand_sum == 21
          puts "#{player.name} has blackjack.\n"
        else
          action = player.get_action
          while action != "s"
            if action == "h"
              new_card = game.deal_card
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

      game.score_round
      game.collect_winnings
      
      # this is messed up
      action = prompt("Round over. Deal again?")
      while action != "y" && action != "n" && action != "q"
        action = prompt("Invalid response. Please type \"y\" to deal again, \"n\" to start a new game, or \"q\" to quit.")
        if action == "n"
          break;
        elsif action == "q"
          game_live = false
        else
          game.new_round
        end
      end

      # hackish; maybe should throw an error above?
      if action == "n" || action == "q"
        break;
      end
    end
  end
  puts "Thanks for playing!"
end