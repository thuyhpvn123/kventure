// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {KVenture} from "../src/hh2.sol";
import {USDT} from "../src/USDT.sol";
import {MasterPool} from "../src/MasterPool.sol";
import {MatrixTree} from "../src/tree.sol";

contract KVentureTest is Test {
    KVenture public kventure;
    USDT public usdt;
    MatrixTree public matrixTree;
    MasterPool public masterPool;

    address[] public addressList;
    address public deployOwner;

    function initAddressListToCall() public {
        // ToDO: Khởi tạo 10 địa chỉ để  call
        for (uint256 index = 0; index < 10; index++) {
            addressList.push(vm.addr(index + 1));
        }
    }

    // Function này dùng để  set up  test - Giống constructor của smart contract
    function setUp() public {
        // Init addressList to call
        initAddressListToCall();

        // Set config
        deployOwner = addressList[0];

        vm.startPrank(deployOwner); // Set caller msg.sender là deployOwner
        usdt = new USDT();
        masterPool = new MasterPool(address(usdt));
        matrixTree = new MatrixTree();
        kventure = new KVenture(); // deployOwner là chủ của smart contract KVenture

        kventure.initialize(address(usdt), address(masterPool), address(matrixTree));

        vm.stopPrank(); // Dừng set msg.sender là deployOwner
    }

    // function test phải bắt buộc bắt đầu bằng chữ test và các biến môi trường độc lập với nhau
    // môi trường chung sẽ được set trong function setup
    function testSetUp() public {
        assertEq(kventure.owner(), deployOwner, "Err in set up deployment");
    }
}
