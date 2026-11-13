#!/bin/bash

PSQL=(psql -X -qAt -U freecodecamp -d number_guess -v ON_ERROR_STOP=1)

printf '%s\n' 'Enter your username:'
IFS= read -r USERNAME || exit 0

if ! STATS=$("${PSQL[@]}" -F '|' -v username="$USERNAME" <<'SQL'
SELECT COUNT(g.game_id), MIN(g.guesses)
FROM users AS u
JOIN games AS g USING (user_id)
WHERE u.username = :'username'
GROUP BY u.user_id;
SQL
); then
  exit 1
fi

if [[ -n "$STATS" ]]; then
  IFS='|' read -r GAMES_PLAYED BEST_GAME <<< "$STATS"
  printf 'Welcome back, %s! You have played %s games, and your best game took %s guesses.\n' \
    "$USERNAME" "$GAMES_PLAYED" "$BEST_GAME"
else
  printf 'Welcome, %s! It looks like this is your first time here.\n' "$USERNAME"
fi

# Reject the extra values so all 1,000 outcomes are equally likely.
while (( (DRAW = RANDOM) >= 32000 )); do
  :
done
SECRET_NUMBER=$(( DRAW % 1000 + 1 ))
NUMBER_OF_GUESSES=0

printf '%s\n' 'Guess the secret number between 1 and 1000:'

while IFS= read -r GUESS; do
  (( NUMBER_OF_GUESSES += 1 ))

  if [[ ! "$GUESS" =~ ^([+-]?)0*([0-9]+)$ ]]; then
    printf '%s\n' 'That is not an integer, guess again:'
    continue
  fi

  SIGN=${BASH_REMATCH[1]}
  DIGITS=${BASH_REMATCH[2]}

  if [[ "$SIGN" == '-' ]]; then
    printf "%s\n" "It's higher than that, guess again:"
  elif (( ${#DIGITS} > 4 )) || (( 10#$DIGITS > SECRET_NUMBER )); then
    printf "%s\n" "It's lower than that, guess again:"
  elif (( 10#$DIGITS < SECRET_NUMBER )); then
    printf "%s\n" "It's higher than that, guess again:"
  else
    if ! "${PSQL[@]}" -v username="$USERNAME" -v guesses="$NUMBER_OF_GUESSES" <<'SQL'
BEGIN;

INSERT INTO users (username)
VALUES (:'username')
ON CONFLICT (username) DO NOTHING;

INSERT INTO games (user_id, guesses)
SELECT user_id, :'guesses'::INT
FROM users
WHERE username = :'username';

COMMIT;
SQL
    then
      exit 1
    fi

    printf 'You guessed it in %s tries. The secret number was %s. Nice job!\n' \
      "$NUMBER_OF_GUESSES" "$SECRET_NUMBER"
    exit 0
  fi
done
