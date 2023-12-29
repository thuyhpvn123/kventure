// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import "@openzeppelin/contracts@v4.9.0/utils/math/Math.sol";
// import {console} from "forge-std/console.sol";
import "./NodeStruct.sol";
// abstract contract NodeStruct{
//     struct Node {
//         address value;
//         uint256 leftChild; //Index of arryList
//         uint256 rightChild; //Index of arryList
//     }
// }

contract MatrixTree is NodeStruct{
    using Math for uint256;

    // Node[] public nodeList;
    // mapping(address => uint256) public indexOfNode; // realIndex = indexOfNode - 1;

    function insertMember(address newMember) external returns (bool) {
        require(indexOfNode[newMember] == 0, "Member Exist");

        // root
        if (nodeList.length == 0) {
            initMember(newMember);
            return true;
        }

        uint256 parentPosition = getInsertedParent();

        if (nodeList[parentPosition - 1].leftChild == 0) {
            nodeList[parentPosition - 1].leftChild = initMember(newMember);
        } else {
            uint256 newPosition = initMember(newMember);
            nodeList[parentPosition - 1].rightChild = newPosition;
        }

        return true;
    }
    
    function initMember(address newMember) internal returns (uint256) {
        Node memory newNode = Node({
            value: newMember,
            leftChild: 0,
            rightChild: 0
        });
        nodeList.push(newNode);
        indexOfNode[newMember] = nodeList.length;
        return nodeList.length;
    }

    function getInsertedParent() public view returns (uint256 parentPosition) {
        uint256 newChildPosition = nodeList.length + 1;
        uint256 depth = getDepth(nodeList.length + 1);
        if (newChildPosition < 2 ** (depth - 1) + 2 ** depth) {
            return newChildPosition - 2 ** (depth - 1);
        } else {
            return newChildPosition - 2 ** (depth - 1) * 2;
        }
    }

    function getDepth(uint256 noElement) public pure returns (uint256) {
        return Math.log2(noElement);
    }

    function getNodeInfo(
        uint256 _indexOfNode
    ) public view returns (NodeStruct.Node memory) {
        return nodeList[_indexOfNode - 1];
    }
    function getIndexOfNode(address addNode)public view returns(uint256 ){
        return indexOfNode[addNode];
    }
    function getParentIndex(address addNode)public view returns(uint256 parentPosition){
        require(indexOfNode[addNode]>1,"this is the root node");
        uint256 newChildPosition = indexOfNode[addNode];
        uint256 depth = getDepth(indexOfNode[addNode]);
        if (newChildPosition < 2 ** (depth - 1) + 2 ** depth) {
            return newChildPosition - 2 ** (depth - 1);
        } else {
            return newChildPosition - 2 ** (depth - 1) * 2;
        }
    }
    function getParentAdd(address addNode)public view returns(address parentAdd){
        uint256 parentPosition = getParentIndex(addNode);
        return nodeList[parentPosition-1].value;
    }
}
