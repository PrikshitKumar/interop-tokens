// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IProxy} from "../interface/IProxy.sol";
import {IImplementationAuthority} from "../interface/IImplementationAuthority.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

abstract contract AbstractProxy is IProxy, Initializable {

    /**
     *  @dev See {IProxy-setImplementationAuthority}.
     */
    function setImplementationAuthority(address _newImplementationAuthority) external override {
        require(msg.sender == getImplementationAuthority(), "only current implementationAuthority can call");
        require(_newImplementationAuthority != address(0), "invalid argument - zero address");
        require(
            (IImplementationAuthority(_newImplementationAuthority)).getImplementation() != address(0), "invalid Implementation Authority");
        _storeImplementationAuthority(_newImplementationAuthority);
        emit ImplementationAuthoritySet(_newImplementationAuthority);
    }

    /**
     *  @dev See {IProxy-getImplementationAuthority}.
     */
    function getImplementationAuthority() public override view returns(address) {
        address implemAuth;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            implemAuth := sload(0x821f3e4d3d679f19eacc940c87acf846ea6eae24a63058ea750304437a62aafc)
        }
        return implemAuth;
    }

    /**
     *  @dev store the implementationAuthority contract address using the ERC-3643 implementation slot in storage
     *  the slot storage is the result of `keccak256("ERC-3643.proxy.beacon")`
     */
    function _storeImplementationAuthority(address implementationAuthority) internal {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            sstore(0x821f3e4d3d679f19eacc940c87acf846ea6eae24a63058ea750304437a62aafc, implementationAuthority)
        }
    }

}
