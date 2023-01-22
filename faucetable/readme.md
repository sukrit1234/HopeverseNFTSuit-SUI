## Faucetable Methods
Add function to every sui::Coin can be faucetable.
  + **create_faucetable<T: drop>(...)** Create faucetable shared object (will use in two below methods) that define total supply for use as faucet and amount per faucet request.
  + **refill_faucet<T: drop>(...)** Refill faucet total supply on faucetable shared object.
  + **request_faucet<T:drop>(...)** Request faucet for user.
