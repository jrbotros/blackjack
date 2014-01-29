#!/usr/bin/env ruby

# go through and convert things to ternary
# A needs to be either value
# push doesn't score correctly
# prevent decimal bet

require('pp')

# constants
INIT_CASH = 1000
NUM_DECKS = 1
CARD_SUITS = %w(Hearts Diamonds Spades Clubs)
CARD_RANKS = %w(Ace 2 3 4 5 6 7 8 9 10 Jack Queen King)
CARD_VALUES = [11, 2, 3, 4, 5, 6, 7, 8, 9, 10, 10, 10, 10]
INT_REGEX = /^[0-9]+$/

def prompt(*args)
  puts(*args)
  gets.chomp
end

# for yes/no questions
def bool_prompt(message)
  action = prompt(message + " [y/n]")
  while action != "y" && action != "n"
    action = prompt("Invalid response. Please type \"y\" or \"n\".")
  end
  action == "n" ? false : true
end

class Game
  attr_accessor :cards, :players

  def initialize
    num_players = prompt("How many players are at the table?\n")
    while num_players.to_i <= 0 || (INT_REGEX =~ num_players).nil?
      num_players = prompt("Please enter a valid integer greater than 0.\n")
    end
    num_players = num_players.to_i
    
    # this should save time instead of calculating the length of the players list, right?
    @players = []
    num_players.times do |count|
      name = prompt("Player #{count + 1} name:")
      @players.push(Player.new(name))
    end

    # dealer will be the last to play each round; his "cash" will represent the casino's winnings
    # dealer's bet is set to 1 for error checking later, should fix?
    @players.push(Player.new("Dealer", true, 0))

    # populate the "shoe" with cards
    @cards = []
    NUM_DECKS.times do
      CARD_SUITS.each do |suit|
        CARD_RANKS.each_with_index do |rank, i|
          @cards.push(Card.new(suit, rank, CARD_VALUES[i]))
        end
      end
    end
  end

  # active players (cash > 0)
  def live_players
    @players.select {|player| player.live}
  end

  # return cards to the shoe and shuffle
  def new_round
    live_players.each do |player|
      player.hands.each do |hand|
        @cards += hand.cards
      end
      player.hands = []
    end
    @cards = @cards.shuffle
  end

  def deal_cards
    live_players.each do |player|
      puts "===== #{player.name}'s Turn ====="
      new_hand = Hand.new

      # allow player to bet any positive integer that won't bankrupt them
      if !player.dealer
        bet = prompt("#{player.name}: You currently have $#{player.cash}. What would you like to bet?")
        while (bet.to_i <= 0 || bet.to_i > player.cash)|| (INT_REGEX =~ bet).nil?
          bet = prompt("#{player.name}: Please enter a valid bet from $1 to $#{player.cash}.")
        end
        new_hand.bet = bet.to_i
      end

      # deal first hand
      2.times do |count|
        new_card = @cards.pop
        new_hand.cards.push(new_card)

        # don't show the dealer's first card
        new_card.visible = false if player.dealer && count == 0

        puts "#{player.name} was dealt the #{new_card.name}."
      end
      player.hands.push(new_hand)

      if new_hand.score == 21
        puts "Blackjack!"
        player.blackjack = true
        # if player is dealer, end game
      elsif !player.dealer && new_hand.pair      
        player.hands += new_hand.split(@cards)
      end
      puts "\n"
    end
  end

  def play_round
    live_players.each do |player|
      puts "===== #{player.name}'s Turn ====="
      player.hands.each_with_index do |hand, i|
        if player.hands.length > 1
          puts "***** Hand #{i + 1} *****"
        end
        if hand.score == 21
          puts "#{player.name} has blackjack.\n"
        elsif hand.more_cards
          action = hand.get_action(player)
          while action != "s" && hand.more_cards
            if action == "h"
                new_card = @cards.pop
                hand.cards.push(new_card)
                puts "#{player.name} drew the #{new_card.name}."
              if hand.score > 21
                puts "Bust!"
                break
              elsif hand.score == 21
                puts "21!"
                break
              else
                action = hand.get_action(player)
              end
            elsif action == "d"
              # should only be able to double down once
              if hand.doubled_down
                puts "You've already doubled down."
              elsif player.total_bet + hand.bet < player.cash
                hand.bet *= 2
                hand.doubled_down = true
                new_card = @cards.pop
                hand.cards.push(new_card)
                hand.more_cards = false
                puts "Double down! Your new bet is #{hand.bet}."
                puts "You were dealt the #{new_card.name}."
              else
                puts "You don't have the cash to double down. Your bet is #{hand.bet}."
              end
              action = hand.get_action(player)
            else
              action = prompt("Invalid response. Please type \"h\" to hit, \"s\" to stand, or \"d\" to double down.")
            end
          end
        end
      end
    end
  end

  def score_round
    # what about when dealer gets blackjack? need to account for some extra rules here
    dealer_score = live_players.last.hands[0].score
    live_players[0..-2].each do |player|
      player.hands.each do |hand|
        if dealer_score <= 21
          if hand.score <= 21
            # use an enum
            if hand.score > dealer_score
              hand.won = true
            elsif hand.score == dealer_score
              hand.won = nil
            else
              hand.won = false
            end
          else
            # player busted
            hand.won = false
          end
        else
          # dealer busted
          if hand.score <= 21
            hand.won = true
          else
            hand.won = false
          end
        end
      end
    end
  end

  # collect bets iteratively at end
  def collect_winnings
    puts "===== Round Over ====="
    dealer = @players.last
    live_players[0..-2].each do |player|
      player.hands.each do |hand|
        if hand.won.nil?
          puts "#{player.name}: Push. Dealer has returned your bet. You have $#{player.cash}."
        elsif hand.won
          player.cash += hand.bet
          dealer.cash -= hand.bet
          puts "#{player.name}: You win $#{hand.bet}! You now have $#{player.cash}."
        else
          player.cash -= hand.bet
          dealer.cash += hand.bet
          if player.cash <= 0
            player.live = false
            puts "#{player.name}: You've lost all of your money! Better luck next time."
            break
          else
            puts "#{player.name}: You lose #{hand.bet}. You have $#{player.cash} remaining."
          end
        end
      end
    end
  end

end

class Player
  attr_accessor :bet, :cash, :hands, :live, :won, :blackjack
  attr_reader :name, :dealer

  def initialize(name, dealer = false, cash = INIT_CASH)
    @name = name
    @dealer = dealer
    @cash = cash
    @hands = []
    @live = true
    @blackjack = false
  end

  def total_bet
    @hands.map {|hand| hand.bet}.reduce(:+)
  end
end

class Hand
  attr_accessor :cards, :won, :bet, :doubled_down, :more_cards

  def initialize(cards = [], bet = 0, doubled_down = false, more_cards = true)
    @cards = cards
    @won = nil
    @bet = bet
    @doubled_down = doubled_down
    @more_cards = more_cards
  end

  def pair
    @cards.map {|card| card.value % 10}.reduce(:==) if @cards.length == 2
  end

  def sum
    @cards.map {|card| card.value}.reduce(:+)
  end

  def shrink_aces
    @cards.each do |card|
      if card.rank == "Ace" && card.value == 11
        card.value = 1
        break if sum <= 21
      end
    end
  end

  def score
    if sum > 21
      shrink_aces
    end
    sum
  end

  def get_action(player)
    show
    if player.dealer
      if score < 17
        action = "h"
        puts "The dealer has #{score} points and must hit."
      else
        action = "s"
        puts "The dealer has #{score} points and must stand."
      end
      sleep(1)
    else
      action = prompt("#{player.name}\'s turn: You currently have #{score} points. What would you like to do?")
    end
    action
  end

  def show
    @cards.each do |card|
      card.visible = true
      puts "#{card.name}\n"
    end
  end

  def split(cards)
    split = bool_prompt("You have two cards of the same value! Would you like to split?")
    new_hands = []
    if split
      old_card = @cards.pop
      new_card = cards.pop
      @cards.push(new_card)
      puts "You were dealt the #{new_card.name}. You now have:"
      show

      sleep(1)

      new_card = cards.pop
      new_hand = Hand.new([old_card, new_card], @bet, @doubled_down, @more_cards)
      new_hands.push(new_hand)
      puts "You were dealt the #{new_card.name}. You now have:"
      new_hand.show

      sleep(1)

      if old_card.rank == "Ace"
        new_hand.more_cards = @more_cards = false
      end

      new_hands += split(cards) if pair
      new_hands += new_hand.split(cards) if new_hand.pair
    end
    new_hands
  end
end

class Card
  attr_accessor :visible, :value
  attr_reader :suit, :rank

  def initialize(suit, rank, value, visible = true)
    @suit = suit
    @rank = rank
    @value = value
    @visible = visible
  end

  def name
    @visible ? "#{@rank} of #{@suit}" : "hole card"
  end
end

if __FILE__ == $0
  program_live = true

  while program_live
    game = Game.new

    game_live = true

    while game_live && game.live_players.length > 1
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