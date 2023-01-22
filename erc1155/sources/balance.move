//Balance for ERC1155 because of sui implementation does not support for Multitoken.
module erc1155::balance {

    /// For when trying to destroy a non-zero balance.
    const ENonZero: u64 = 0;

    /// For when an overflow is happening on Supply operations.
    const EOverflow: u64 = 1;

    /// For when trying to withdraw more than there is.
    const ENotEnough: u64 = 2;

    /// A Supply of T. Used for minting and burning.
    /// Wrapped into a `TreasuryCap` in the `Coin` module.
    struct Supply<phantom T> has store {
        value: u64
    }

    /// Storable balance - an inner struct of a Coin type.
    /// Can be used to store coins which don't need the key ability.
    struct Balance<phantom T> has store {
        value: u64
    }

    /// Get the amount stored in a `Balance`.
    public fun value<T>(self: &Balance<T>): u64 {
        self.value
    }

    /// Get the `Supply` value.
    public fun supply_value<T>(supply: &Supply<T>): u64 {
        supply.value
    }

    /// Create a new supply for type T.
    public fun create_supply<T: drop>() : Supply<T> {
        Supply { value: 0 }
    }

    /// Increase supply by `value` and create a new `Balance<T>` with this value.
    public fun increase_supply<T>(self: &mut Supply<T>, value: u64): Balance<T> {
        assert!(value < (18446744073709551615u64 - self.value), EOverflow);
        self.value = self.value + value;
        Balance { value }
    }

    /// Burn a Balance<T> and decrease Supply<T>.
    public fun decrease_supply<T>(self: &mut Supply<T>, balance: Balance<T>): u64 {
        let Balance { value } = balance;
        assert!(self.value >= value, EOverflow);
        self.value = self.value - value;
        value
    }

    /// Create a zero `Balance` for type `T`.
    public fun zero<T>(): Balance<T> {
        Balance { value: 0 }
    }

    spec zero {
        aborts_if false;
        ensures result.value == 0;
    }

    /// Join two balances together.
    public fun join<T>(self: &mut Balance<T>, balance: Balance<T>): u64 {
        let Balance { value } = balance;
        self.value = self.value + value;
        self.value
    }

    spec join {
        ensures self.value == old(self.value) + balance.value;
        ensures result == self.value;
    }

    /// Split a `Balance` and take a sub balance from it.
    public fun split<T>(self: &mut Balance<T>, value: u64): Balance<T> {
        assert!(self.value >= value, ENotEnough);
        self.value = self.value - value;
        Balance { value }
    }

    spec split {
        aborts_if self.value < value with ENotEnough;
        ensures self.value == old(self.value) - value;
        ensures result.value == value;
    }

    /// Destroy a zero `Balance`.
    public fun destroy_zero<T>(balance: Balance<T>) {
        assert!(balance.value == 0, ENonZero);
        let Balance { value: _ } = balance;
    }

    spec destroy_zero {
        aborts_if balance.value != 0 with ENonZero;
    }
}