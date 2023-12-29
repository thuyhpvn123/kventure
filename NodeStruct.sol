pragma solidity 0.8.19;
abstract contract NodeStruct{
    struct Node {
        address value;
        uint256 leftChild; //Index of arryList
        uint256 rightChild; //Index of arryList
    }
    Node[] public nodeList;
    mapping(address => uint256) public indexOfNode; // realIndex = indexOfNode - 1;

}