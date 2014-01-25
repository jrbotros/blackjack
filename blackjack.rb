#!/usr/bin/env ruby

INIT_CASH = 1000

RANKS = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 10, 10, 10]

# RANKS = %w(A 2 3 4 5 6 7 8 9 10 J Q K)

SUITS = %w(Hearts Diamonds Spades Clubs)

def prompt(*args)
  print(*args)
  gets.chomp
end

class Game
  attr_reader :num_players
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

    # is there an ideal number of decks per person playing?
    num_decks = 1

    @cards = []
    num_decks.times do
      SUITS.each do |suit|
        RANKS.each do |rank|
          @cards.push(Card.new(suit, rank))
        end
      end
    end
  end

  def live_players
    @players.select {|player| player.live}
  end

  def shuffle
    @cards = @cards.shuffle
  end

  def deal_card
    # this breaks if there are no cards
    @cards.pop
  end

  def reset_cards
    @players.each do |player|
      @cards += player.hand
      player.hand = []
    end
    shuffle
  end
end

class Player
  attr_accessor :hand, :live
  attr_reader :name, :cash

  def initialize(name)
    @live = true
    @name = name
    @cash = INIT_CASH
    @hand = []
  end

  def hand_sum
    return @hand.map {|card| card.rank}.reduce(:+)
  end
end

class Card
  attr_reader :suit, :rank

  def initialize(suit, rank)
    @suit = suit
    @rank = rank
  end

  def name
    "#{@rank} of #{@suit}"
  end

end

if __FILE__ == $0
  game_live = true
  while true
    if game_live
      game = Game.new
    else
      break
    end
    while true
      game.reset_cards
      game.players.each do |player|
        player.live = true
        2.times do
          new_card = game.deal_card
          player.hand.push(new_card)
          puts "#{player.name} was dealt the #{new_card.name}."
        end
      end

      game.players.each do |player|
        if game.live_players.length == 1
          break;
        end
        # need error checking here
        action = nil
        action = prompt("#{player.name}\'s turn: You currently have #{player.hand_sum} points. What would you like to do?")
        while action != "s"
          if action == "h"
            new_card = game.deal_card
            player.hand.push(new_card)
            puts "You drew the #{new_card.name}."
            if player.hand_sum > 21
              puts "Bust!"
              player.live = false
              break
            elsif player.hand_sum == 21
              puts "Blackjack!"
              break
            else
              action = prompt("#{player.name}\'s turn: You currently have #{player.hand_sum} points. What would you like to do?")
            end
          elsif action != "s"
            action = prompt("Invalid response. Please type \"h\" to hit or \"s\" to stand.")
          end
        end
      end

      # can optimize this condition
      if game.live_players.length > 1
        winners = []
        losers = []
        game.live_players.each do |player|
          # what happens in a tie?
          if winners.length == 0
            winners = [player]
          else
            if player.hand_sum > winners[0].hand_sum
              losers += winners
              winners = [player]
            elsif player.hand_sum == winners[0].hand_sum
              winners.push(player)
            else
              losers.push(player)
            end
          end
        end
        puts winners[0].name
        if winners.length == 1
          puts "#{winners[0].name} wins!"
        else
          puts "Push. Your bets have been returned."
        end
      else
          puts "#{game.live_players[0].name} wins!"
      end

      action = prompt("Round over. Deal again?")
      while action != "y" && action != "n" && action != "q"
        action = prompt("Invalid response. Please type \"y\" to deal again, \"n\" to start a new game, or \"q\" to quit.")
        if action == "n"
          break;
        elsif action == "q"
          game_live = false
        else
          game.reset_cards
        end
      end

      # jank
      if action == "n" || action == "q"
        break;
      end
    end
    puts "Thanks for playing!"
  end
end