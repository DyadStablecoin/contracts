

library DyadHooks {

    uint256 internal constant EXTENSION_ENABLED = 1;
    uint256 internal constant AFTER_DEPOSIT = 2;
    uint256 internal constant AFTER_WITHDRAW = 4;
    uint256 internal constant AFTER_MINT = 8;
    uint256 internal constant AFTER_BURN = 16;
    uint256 internal constant AFTER_REDEEM = 32;

    function hookEnabled(uint256 flags, uint256 hook) internal pure returns (bool) {
        return (flags & hook) == hook;
    }

    function enableExtension(uint256 flags) internal pure returns (uint256) {
        return flags | EXTENSION_ENABLED;
    }

    function disableExtension(uint256 flags) internal pure returns (uint256) {
        return flags & ~EXTENSION_ENABLED;
    }
}