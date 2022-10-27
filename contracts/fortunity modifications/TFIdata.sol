// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

import { PerpMath } from "./lib/PerpMath.sol";
//truflation import

contract TFI {

    uint256 internal truflationData;

    // External Non-View

    function initialize(

    ) external initializer {

    }

    // External View

    function getPriceIndex () external view returns (uint256) {
        return _priceIndex;
    } 
}