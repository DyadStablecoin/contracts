
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";
import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

contract TanhTest is Test {
    using SafeCastLib for uint256;
    using SafeCastLib for int256;
    using FixedPointMathLib for uint256;
    using FixedPointMathLib for int256;

    function testTanh1() public {
        uint256 x = 1e18;
        uint256 y = _tanh(x);
               // 0.761594155955764888
        assertEq(y, 761594155955764888);
        console2.log(x / 1e18, y);
    }

    function testTanh2() public {
        uint256 x = 2e18;
        uint256 y = _tanh(x);
        assertEq(y, 964027580075816884);
        console2.log(x / 1e18, y);
    }

    function testTanh3() public {
        uint256 x = 3e18;
        uint256 y = _tanh(x);
        assertEq(y, 995054753686730451);
        console2.log(x / 1e18, y);
    }

    function testTanh4() public {
        uint256 x = 4e18;
        uint256 y = _tanh(x);
        assertEq(y, 999329299739067043);
        console2.log(x / 1e18, y);
    }

    function testTanh5() public {
        uint256 x = 5e18;
        uint256 y = _tanh(x);
        assertEq(y, 999909204262595131);
        console2.log(x / 1e18, y);
    }

    function testTanh6() public {
        uint256 x = 6e18;
        uint256 y = _tanh(x);
        assertEq(y, 999987711650795570);
        console2.log(x / 1e18, y);
    }

    function testTanh7() public {
        uint256 x = 7e18;
        uint256 y = _tanh(x);
        assertEq(y, 999998336943944671);
        console2.log(x / 1e18, y);
    }

    function testTanh8() public {
        uint256 x = 8e18;
        uint256 y = _tanh(x);
        assertEq(y, 999999774929675889);
        console2.log(x / 1e18, y);
    }

    function testTanh9() public {
        uint256 x = 9e18;
        uint256 y = _tanh(x);
        assertEq(y, 999999969540040974);
        console2.log(x / 1e18, y);
    }

    function testTanh10() public {
        uint256 x = 10e18;
        uint256 y = _tanh(x);
        assertEq(y, 999999995877692763);
        console2.log(x / 1e18, y);
    }

    /// @notice Computes the hyperbolic tangent of a number.
    /// @param x The number to compute the hyperbolic tangent of.
    /// @return The hyperbolic tangent of x.
    /// @dev tanh can be computed as (exp(x) - exp(-x)) / (exp(x) + exp(-x))
    ///      but we need to be careful with overflow: x must be less than 135 * WAD.
    function _tanh(uint256 x) internal pure returns (uint256) {
      int256 xInt = x.toInt256();

      if (xInt > 135305999368893231588) {
        xInt = 135305999368893231588;
      }
      int256 expX = xInt.expWad();
      int256 invExpX = (xInt * -1).expWad();

      return (((expX - invExpX) * 1e18) / (expX + invExpX)).toUint256();
    }
}
