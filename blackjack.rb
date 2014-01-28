#!/usr/bin/env ruby

# go through and convert things to ternary
# catch when user bets too much, non-integer, or runs out of cash
# A needs to be either value
# push doesn't score correctly

require('pp')

INIT_CASH = 1000

NUM_DECKS = 1

CARD_SUITS = %w(Hearts Diamonds Spades Clubs)

# CARD_RANKS = %w(Ace 2 3 4 5 6 7 8 9 10 Jack Queen King)
CARD_RANKS = %w(Ace Ace Ace Ace Ace Ace Ace 8 9 10 Jack Queen King)

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
  attr_accessor :players, :shoe, :cards

  def initialize
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

    @cards = []
    NUM_DECKS.times do
      CARD_SUITS.each do |suit|
        CARD_RANKS.each_with_index do |rank, i|
          @cards.push(Card.new(suit, rank, CARD_VALUES[i]))
        end
      end
    end
  end

  def live_players
    @players.select {|player| player.live}
  end

  def new_round
    live_players.each do |player|
      player.hands.each do |hand|
        @cards += hand.cards
      end
      player.hands = []
      player.bet = nil
    end
    @cards = @cards.shuffle
  end

  def deal_cards
    live_players.each do |player|
      # could be prettier
      player.bet = player.dealer ? 1 : prompt("#{player.name}: You currently have $#{player.cash}. What would you like to bet?").to_i
      while !player.dealer && (player.bet < 1 || player.bet > player.cash)
        player.bet = prompt("#{player.name}: Please enter a valid bet from $1 to $#{player.cash}").to_i
      end

      new_hand = Hand.new
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
        # if player is dealer, end game
      elsif !player.dealer && new_hand.pair        
        player.hands += new_hand.split(@cards)
      end
      pp player.hands
      puts "\n"
    end
  end

  def play_round
    live_players.each do |player|
      player.hands.each do |hand|
        if hand.score == 21
          puts "#{player.name} has blackjack.\n"
        else
          action = hand.get_action(player)
          while action != "s"
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
            elsif action != "s"
              action = prompt("Invalid response. Please type \"h\" to hit or \"s\" to stand.")
            end
          end
        end
      end
    end
  end

  def score_round
    # what about when dealer gets blackjack? need to account for some extra rules here
    dealer_score = live_players.last.hands[0].score
    if dealer_score <= 21
      live_players[0..-2].each do |player|
        player.hands.each do |hand|
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
        end
      end
    else
      # dealer busted
      live_players[0..-2].each do |player|
        player.hands.each do |hand|
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
    dealer = @players.last
    live_players[0..-2].each do |player|
      player.hands.each do |hand|
        # don't think this works
        if hand.won.nil?
          puts "#{player.name}: Push. Dealer has returned your bet. You have $#{player.cash}."
        elsif hand.won
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

end

class Player
  attr_accessor :bet, :cash, :hands, :live, :won
  attr_reader :name, :dealer

  def initialize(name, dealer = false, cash = INIT_CASH)
    @name = name
    @dealer = dealer
    @cash = cash
    @hands = []
    @bet = 0
    @live = true
  end
end

class Hand
  attr_accessor :cards, :won

  def initialize(cards = [])
    @cards = cards
    @won = nil
  end

  def pair
    @cards.map {|card| card.rank}.reduce(:==) if @cards.length == 2
  end

  def score
    @cards.map {|card| card.value}.reduce(:+)
  end

  def get_action(player)
    puts "#{player.name}'s hand:"
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
    split = bool_prompt("You have a pair of #{@cards[0].rank}s. Would you like to split?")
    new_hands = []
    if split
      old_card = @cards.pop
      new_card = cards.pop
      @cards.push(new_card)
      puts "You were dealt the #{new_card.rank} of #{new_card.suit}. You know have:"
      show
      new_hands += split(cards) if pair

      new_card = cards.pop
      new_hand = Hand.new([old_card, cards.pop])
      new_hands.push(new_hand)
      puts "You were dealt the #{new_card.rank} of #{new_card.suit}. You now have:"
      show
      new_hands += new_hand.split(cards) if new_hand.pair
    end
    new_hands
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
      
      game_live = game.live_players.length > 1 ? bool_prompt("Round over. Deal again?") : false

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