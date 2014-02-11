#!/usr/bin/env ruby

=begin
  * Blackjack in Ruby
  * Rules according to http://www.pagat.com/banking/blackjack.html
  * Joseph Botros
  * 29 January 2014
=end

INIT_CASH = 1000
INT_REGEX = /^[0-9]+$/
CARD_SUITS = %w(Hearts Diamonds Spades Clubs)
CARD_RANKS = %w(Ace 2 3 4 5 6 7 8 9 10 Jack Queen King)
CARD_VALUES = [11, 2, 3, 4, 5, 6, 7, 8, 9, 10, 10, 10, 10]
NUM_DECKS = 8

def prompt(*args)
  puts(*args)
  gets.chomp
end

def bool_prompt(message)
  action = prompt(message + " [y/n]")
  while action != "y" && action != "n"
    action = prompt("Invalid response. Please type \"y\" or \"n\".")
  end
  action == "n" ? false : true
end

class Card
  attr_reader :suit, :rank, :value

  def initialize(suit, rank, value)
    @suit = suit
    @rank = rank
    @value = value
  end

  def name
    "#{@rank} of #{@suit}"
  end
end

class Hand
  attr_accessor :cards, :bet, :is_split

  def initialize(cards = [], bet = 0, is_split = false)
    @cards = cards
    @bet = bet
    @is_split = is_split
  end

  def pair
    # mod 10 checks for ace pairs
    @cards.map { |card| card.value % 10 }.reduce(:==) if @cards.length == 2
  end

  def score
    sum = @cards.map { |card| card.value }.reduce(:+)
    if sum > 21
      @cards.each do |card|
        if card.value == 11
          sum -= 10
          break if sum < 21
        end
      end
    end
    sum
  end

  def blackjack
    # blackjack must be composed two cards totaling 21, and cannot occur on a hand split from aces
    @cards.length == 2 && score == 21 && !(@is_split && @cards.first.rank == "Ace") 
  end

  def show
    @cards.each do |card|
      puts "#{card.name}\n"
    end
    puts "\n"
  end

  def split(cards)
    puts "===================="
    split_hand = bool_prompt("You have two cards of the same value! Would you like to split?")
    new_hands = []
    if split_hand
      old_card = @cards.pop
      new_card = cards.pop
      @cards.push(new_card)
      @is_split = true

      puts "You were dealt the #{new_card.name}. You now have:"
      show
      sleep(1)

      # split if first hand now contains pair
      new_hands += split(cards) if pair
      new_card = cards.pop
      new_hand = Hand.new([old_card, new_card], @bet, true)
      new_hands.push(new_hand)

      puts "You were dealt the #{new_card.name}. You now have:"
      new_hand.show
      sleep(1)

      # split if second hand now contains pair
      new_hands += new_hand.split(cards) if new_hand.pair
    end
    new_hands
  end
end

class Player
  attr_accessor :cash, :hands
  attr_reader :name

  def initialize(name)
    @name = name
    @cash = INIT_CASH
    @hands = []
  end

  def total_bet
    @hands.map { |hand| hand.bet }.reduce(:+)
  end

  def collect_bet(bet, mult)
    @cash += bet * mult
    if mult > 0
      puts "You win $#{bet * mult}! You now have $#{@cash}."
    elsif mult == 0
      puts "Push. Dealer has returned your bet. You have $#{@cash}."
    else
      if @cash <= 0
        puts "You've lost all of your money! Better luck next time."
      else
        puts "You lose #{bet}. You have $#{@cash} remaining."
      end
    end
    puts "\n"
  end

  def get_action(hand, dealer)
    hand.show
    if dealer
      if hand.score < 17
        action = "h"
        puts "The dealer has #{hand.score} points and must hit."
      else
        action = "s"
        puts "The dealer has #{hand.score} points and must stand."
      end
      sleep(1.5)
    else
      action = prompt("You currently have #{hand.score} points. What would you like to do? [h/s]")
    end
    action
  end
end

class Game
  attr_reader :players, :dealer
  attr_accessor :cards

  def initialize
    num_players = prompt("How many players are at the table?\n")
    while num_players.to_i <= 0 || (INT_REGEX =~ num_players).nil?
      num_players = prompt("Please enter a valid integer greater than 0.\n")
    end
    num_players = num_players.to_i
    
    @players = []
    num_players.times do |count|
      name = prompt("Player #{count + 1} name:")
      @players.push(Player.new(name))
    end

    @dealer = Player.new("Dealer")
    @players.push(@dealer)

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
    @players.select { |player| player.cash > 0 }
  end

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

      if player != @dealer
        bet = prompt("You currently have $#{player.cash}. What would you like to bet?")
        while (bet.to_i <= 0 || bet.to_i > player.cash) || (INT_REGEX =~ bet).nil?
          bet = prompt("Please enter a valid bet from $1 to $#{player.cash}.")
        end
        new_hand.bet = bet.to_i
      end

      2.times do |count|
        new_card = @cards.pop
        new_hand.cards.push(new_card)

        # don't show the dealer's first card
        card_name = player == @dealer && count == 0 ? "the hole card" : new_card.name

        puts "#{player.name} was dealt the #{card_name}."
      end

      player.hands.push(new_hand)

      if new_hand.blackjack
        puts "Blackjack!"
      elsif player != @dealer && new_hand.pair
        player.hands += new_hand.split(@cards)
      end

      puts "\n"
    end
  end

  def play_round
    live_players.each do |player|
      puts "===== #{player.name}'s Turn ====="

      player.hands.each_with_index do |hand, i|
        puts "***** Hand #{i + 1} *****"
        hand.show if player != @dealer

        if hand.blackjack
          puts "#{player.name} has blackjack.\n"

        elsif hand.is_split && hand.cards[0].rank == "Ace"
          puts "You have #{hand.score} points, and no more cards will be dealt to this hand."

        elsif player != @dealer && bool_prompt("Double down?")
          if player.total_bet + hand.bet > player.cash
            puts "You don't have the cash to double down. Your bet is #{hand.bet}."
          else
            hand.bet *= 2
            new_card = @cards.pop
            hand.cards.push(new_card)
            
            puts "Double down! Your new bet is #{hand.bet}."
            puts "You were dealt the #{new_card.name}."
            if hand.score > 21
              puts "Bust!"
            elsif hand.score == 21
              puts "21!"
            else
              puts "You have #{hand.score} points."
            end
            sleep(1)
          end

        else
          action = player.get_action(hand, player == @dealer)

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
                action = player.get_action(hand, player == @dealer)
              end
            else
              action = prompt("Invalid response. Please type \"h\" to hit or \"s\" to stand.")
            end
          end
        end
        sleep(1)
        puts "\n"
      end
    end
  end

  def score_round
    puts "~~~~~ Round Over ~~~~~"
    dealer_hand = @dealer.hands[0]

    live_players[0..-2].each do |player|
      puts "===== #{player.name} ====="

      player.hands.each_with_index do |player_hand, i|
        puts "Hand #{i + 1}:" if player.hands.length > 1

        mult = 0 # bet multiplier

        if dealer_hand.blackjack
          puts "Dealer has blackjack."
          player_hand.blackjack ? mult = 0 : mult = -1

        elsif player_hand.blackjack
          puts "Blackjack!"
          mult = 1.5

        else
          if dealer_hand.score <= 21
            if player_hand.score <= 21
              if player_hand.score > dealer_hand.score
                mult = 1
              elsif player_hand.score == dealer_hand.score
                mult = 0
              else
                mult = -1
              end
            else
              # player busted
              mult = -1
            end
          else
            # dealer busted
            player_hand.score <= 21 ? mult = 1 : mult = -1
          end
        end

        player.collect_bet(player_hand.bet, mult)
      end
    end
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
      
      game_live = bool_prompt("Round over. Deal again?")
      program_live = bool_prompt("New game?") if !game_live
      break if !program_live
    end
  end

  puts "Thanks for playing!"
end