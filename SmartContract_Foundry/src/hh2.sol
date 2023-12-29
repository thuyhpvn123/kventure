pragma solidity 0.8.19;
import "@openzeppelin/contracts-upgradeable@v4.9.0/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts@4.9.0/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable@v4.9.0/proxy/utils/Initializable.sol";
import {IMasterPool} from "./MasterPool.sol";
import "@openzeppelin/contracts@v4.9.0/utils/math/Math.sol";
import "./tree.sol";
import "hardhat/console.sol";

contract KVentureStorage {
    struct SubcribeInfo {
        bytes32 codeRef;
    } 
    // struct Node {
    //     address value;
    //     uint256 leftChild; //Index of arryList
    //     uint256 rightChild; //Index of arryList
    // }
    address public usdt;
    address public masterPool;
    MatrixTree public matrixtree;
    uint public totalUser;
    enum Rank {Unranked, Bronze, Silver,Gold,Platinum,Diamond,crownDiamond}

    mapping(address => uint8)public ranks; //0-6
    mapping(bytes32 => address) public mRefCode;
    mapping(address => SubcribeInfo) public mSubInfo;
    mapping(address => address[]) childrens;
    mapping(address => address[]) childrensMatrix;
    mapping(address => address) line; //parent
    mapping(address => address) public lineMatrix; //parent matrix    //nhớ xoá public
    mapping(address => bool) isActive;
    mapping(address => uint256) public totalSubcriptionBonus;
    mapping(address => uint256) public totalMatrixBonus;
    mapping(address => bool) public mSub;
    mapping(address => mapping(uint32 => uint256)) public mDailyMembers; // address => day => dailyMembers
    mapping(address => uint256) public mtotalMember;
    mapping(address => uint256) public currentMembersForLevelUp;

    uint256[] public totalMemberRequiedToRankUps =[0,2,20,100,500,2_500,50_000];
    uint256[] public totalMemberF1RequiedToRankUps = [0,0,10,30,100,0,0];
    uint256[] public subRequired = [0,0,3,3,3,3,0];
    uint256[] public totalMaxMembers1BranchToRankUp = [0,0,0,30,150,500,10_000];

    uint256[] public comDirectRate = [500, 100, 50, 50, 30, 20, 20, 10, 10, 10]; //0.5% => (5% / 10) = 5/(10^3) 
    uint256 comMatrixRate = 25;
    uint256 public usdtDecimal = 10**6; 
    uint registerFee = 40 * usdtDecimal;
    uint subcriptionFee = 10 * usdtDecimal;
    uint32 public day = 1; 

    event Subcribed(address user,uint id);
    event SubcriptionBonus(address parent, address sub, uint amountUsdt, uint date);
    event MatrixBonus(address parent, address sub, uint amountUsdt, uint date);

    uint256 public totalSubscriptionPayment; 
    uint256 public totalMatrixPayment; 
    uint256 public maxLineForMatrixBonus = 15;
    // Node[] public nodeList;
    // mapping(address => uint256) public indexOfNode; // realIndex = indexOfNode - 1;
}
contract KVenture is Initializable, OwnableUpgradeable, KVentureStorage {


    constructor() payable {}
    function initialize(address _usdt, address _masterPool,address _matrixtree) public initializer {
        usdt = _usdt;
        masterPool = _masterPool;
        matrixtree = MatrixTree(_matrixtree);

         __Ownable_init();

        totalMemberRequiedToRankUps =[0,2,20,100,500,2_500,50_000];
        //levelMaxUpLine =
        totalMemberF1RequiedToRankUps = [0,0,10,30,100,0,0];
        subRequired = [0,0,3,3,3,3,0];
        totalMaxMembers1BranchToRankUp = [0,0,0,30,150,500,10_000];
        comDirectRate = [50, 10, 5, 5, 3, 2, 2, 1, 1, 1]; //0.5% => (5% / 10) = 5/(10^3) 
        comMatrixRate = 25;
        usdtDecimal = 10**6; 
        registerFee = 40 * usdtDecimal;
        subcriptionFee =10 * usdtDecimal;
        day = 1;
        maxLineForMatrixBonus = 15;
    }
    modifier onlySub() {
        require(mSub[msg.sender] == true, 'MetaNode: Please Subcribe First');
        _;
    }
    modifier onlyNotSub() {
        require(mSub[msg.sender] == false, "MetaNode: Only for non-subscribers");
        _;
    }
    function setMatrixTree(address _matrixtree) external onlyOwner {
        matrixtree = MatrixTree(_matrixtree);
    } 
    function SetUsdt(address _usdt) external onlyOwner {
        usdt = _usdt;
    } 
    function SetMasterPool(address _masterPool) external onlyOwner {
        masterPool = _masterPool;
    }
    function setSubFee(uint _subFee) external onlyOwner {
        subcriptionFee = _subFee;
    }
    function setRegisterFee(uint _registerFee) external onlyOwner {
        registerFee = _registerFee;
    }
    event eAddHeadRef(address user, bytes32 codeRef);
    function AddHeadRef(bytes32 codeRef)  external onlyNotSub  {
        require(mRefCode[codeRef] != address(0), 'MetaNode: Invalid Refferal Code');
        line[msg.sender] = mRefCode[codeRef];
        emit eAddHeadRef(msg.sender, codeRef);
    }


    function Register() external returns(bool) {
        require(mSub[msg.sender] == false, "Registered");
        uint256 firstFee = registerFee + subcriptionFee;
        require(IERC20(usdt).balanceOf(msg.sender) >= firstFee, "Invalid Balance");
        IERC20(usdt).transferFrom(msg.sender,masterPool,firstFee);
        _createSubscription(msg.sender,firstFee);
        _addMatrixTree(msg.sender);
        return true;
    }

    function _createSubscription(address subscriber,uint transferredAmount) internal {
        totalUser++;
        mSub[subscriber] = true;
        mSubInfo[subscriber] = SubcribeInfo({
            codeRef: keccak256(abi.encodePacked(subscriber,block.timestamp, block.prevrandao,totalUser))
        });
        mRefCode[mSubInfo[subscriber].codeRef] = subscriber;

        address parent = line[subscriber];
        if (parent != address(0)) {
            childrens[parent].push(subscriber);
            line[subscriber] = parent;
            _transferDirectCommission(subscriber,transferredAmount);
            _updateDailyMemberQuantity(parent);
        }
        ranks[subscriber] = 0;
        emit Subcribed(subscriber,totalUser);
    }
    function _addMatrixTree(address subscriber) internal {
        matrixtree.insertMember(subscriber);  
        uint256 index =matrixtree.getIndexOfNode(subscriber);
        if ( index >1) {
            address parentMatrix = matrixtree.getParentAdd(subscriber);
            childrensMatrix[parentMatrix].push(subscriber);
            lineMatrix[subscriber] = parentMatrix;
        }
    }
    function _updateDailyMemberQuantity(address user) internal {
        mDailyMembers[user][day] += 1;
    }

    function _transferDirectCommission(address buyer,uint256 _firstFee) internal {
        address parent = line[buyer];
        address child = buyer; 
        uint commAmount;
        bool success; 
        for (uint index = 0; index < comDirectRate.length; index++) 
        {   
            if (parent == address(0)) {
                break;
            }
            if (_isValidLevelForDirect(parent,index+1)) {   
                // Pay commission by subscription
                commAmount = (comDirectRate[index]*_firstFee) / 10**3;
                success = IMasterPool(masterPool).transferCommission(parent, commAmount);
                require(success, "Failed transfer commission"); 
                totalMatrixBonus[parent] += commAmount;
                totalSubscriptionPayment += commAmount;
                // _updateDailyRevenue(parent,commAmount);
                emit SubcriptionBonus(parent, child, commAmount, block.timestamp);            

            }

            // Update quantity of member
            _addMember(child);

            // next iteration
            child = parent;
            parent = line[parent];
        }
    }
    function PaySub () external returns (bool) {
        require(mSub[msg.sender] == true, "Need to register first");
        require(IERC20(usdt).balanceOf(msg.sender) >= subcriptionFee, "Invalid Balance");
        IERC20(usdt).transferFrom(msg.sender,masterPool,subcriptionFee);
        _transferMatrixCommission(msg.sender);
        return true;
    }
    function _transferMatrixCommission(address buyer) internal {
        address parent = lineMatrix[buyer];
        address child = buyer; 
        uint commAmount;
        bool success; 
        for (uint index = 0; index < maxLineForMatrixBonus; index++) 
        {   
            if (parent == address(0)) {
                break;
            }
            if (_isValidLevelForMatrix(parent,index+1)) {   
                // Pay matrix commission 
                commAmount = (comMatrixRate*subcriptionFee) / 10**3;             
                success = IMasterPool(masterPool).transferCommission(parent, commAmount);
                require(success, "Failed transfer commission"); 
                totalSubcriptionBonus[parent] += commAmount;
                totalMatrixPayment += commAmount;
                emit MatrixBonus(parent, child, commAmount, block.timestamp);            

            }

            // next iteration
            child = parent;
            parent = lineMatrix[parent];
        }
    }

    //enum Rank {Unranked, Bronze, Silver,Gold,Platinum,Diamond,CrownDiamond}
        // Check condition of upLine with level
    function _isValidLevelForDirect(address receiver, uint atUpLine) internal view returns(bool) {
 
        if (Rank(ranks[receiver]) == Rank.Unranked && atUpLine <= 1) {
            return true;
        } else if (Rank(ranks[receiver]) == Rank.Bronze && atUpLine <= 2) {
            return true;
        } else if (Rank(ranks[receiver]) == Rank.Silver && atUpLine <= 4) {
            return true;
        } else if (Rank(ranks[receiver]) == Rank.Gold && atUpLine <= 6) {
            return true;
        } else if (Rank(ranks[receiver]) == Rank.Platinum && atUpLine <= 8) {
            return true;
        } else if (Rank(ranks[receiver]) == Rank.Diamond || Rank(ranks[receiver]) == Rank.crownDiamond && atUpLine <= 10) {
            return true;   
        } else {
            return false;
        }
    }
    function _isValidLevelForMatrix(address receiver, uint atUpLine) internal view returns(bool) {
 
        if (Rank(ranks[receiver]) == Rank.Unranked && atUpLine <= 12) {
            return true;
        } else if ((Rank(ranks[receiver]) == Rank.Bronze || Rank(ranks[receiver]) == Rank.Silver) && atUpLine <= 13) {
            return true;
        } else if ((Rank(ranks[receiver]) == Rank.Gold || Rank(ranks[receiver]) == Rank.Platinum) && atUpLine <= 14) {
            return true;
        } else if (Rank(ranks[receiver]) == Rank.Diamond || Rank(ranks[receiver]) == Rank.crownDiamond && atUpLine <= 15) {
            return true;   
        } else {
            return false;
        }
    }

    function _addMember(address childAddress) internal {
        address parentAddress = line[childAddress];
        mtotalMember[childAddress] += 1;
        _updateRank(parentAddress);
        if (ranks[parentAddress] > 6) {
            currentMembersForLevelUp[parentAddress] = _calculateTotalMemberForUpdateLevel(parentAddress); ///???
        }
    }

    function _updateRank(address parentAddress) internal {
        if (ranks[parentAddress] > 6) {
            return;
        }

        uint256 rank = ranks[parentAddress];
        console.log("rrank :",rank);
        uint256 totalMembersForUpdateLevel = _calculateTotalMemberForUpdateLevel(parentAddress);
        console.log("totalMembersForUpdateLevel:",totalMembersForUpdateLevel);
            
        while (rank < 7 && totalMembersForUpdateLevel >= totalMemberRequiedToRankUps[rank+1] ) 
        { 
            console.log("totalMemberRequiedToRankUps:",totalMemberRequiedToRankUps[rank+1]);
            if(_extraConditionForRankUp(parentAddress)){
                ranks[parentAddress] += 1;
                rank += 1;
                console.log("rank +1");
                totalMembersForUpdateLevel = _calculateTotalMemberForUpdateLevel(parentAddress);

            }
        }
        currentMembersForLevelUp[parentAddress] = totalMembersForUpdateLevel;
    }

    function _calculateTotalMemberForUpdateLevel(address parentAddress) internal view returns (uint256) {
        uint256 totalMembersForUpdateLevel = 0;

        for (uint256 i = 0; i < childrens[parentAddress].length; i++) {
            address childAddress = childrens[parentAddress][i];
            console.log("childAddress:",childAddress);
            console.log("mtotalMember[childAddress]:",mtotalMember[childAddress]);
            totalMembersForUpdateLevel += mtotalMember[childAddress];
        }
        console.log("day la totalMembersForUpdateLevel:",totalMembersForUpdateLevel);
        return totalMembersForUpdateLevel;
    }
    function _calculateTotalMemberF1ForUpdateLevel(address parentAddress) internal view returns (uint256) {        
        return childrens[parentAddress].length;
    }
    function _calculateTotalMaxMember1BranchForUpdateLevel(address parentAddress) internal view returns (uint256) {        
        uint256 totalMaxMembers1BranchForUpdateLevel = mtotalMember[childrens[parentAddress][0]];

        for (uint256 i = 1; i < childrens[parentAddress].length; i++) {
            address childAddress = childrens[parentAddress][i];
            if (totalMaxMembers1BranchForUpdateLevel < mtotalMember[childAddress]) {
                    totalMaxMembers1BranchForUpdateLevel = mtotalMember[childAddress];
            }
        }
        
        return totalMaxMembers1BranchForUpdateLevel;
    }

    function _extraConditionForRankUp(address parentAddress)internal returns(bool){
        uint256 rank = ranks[parentAddress];
        uint256 totalMembersF1ForUpdateLevel = _calculateTotalMemberF1ForUpdateLevel(parentAddress);
        uint256 totalMaxMembers1BranchForUpdateLevel = _calculateTotalMaxMember1BranchForUpdateLevel(parentAddress);
        if(childrens[parentAddress].length >= subRequired[rank]){
            console.log("dieu kien1",childrens[parentAddress].length);
            return true;
        }else if(totalMembersF1ForUpdateLevel>=totalMemberF1RequiedToRankUps[rank] ){       //tổng người bảo trợ
            console.log("dieu kien2:",totalMembersF1ForUpdateLevel);
            return true;
        }else if(totalMaxMembers1BranchForUpdateLevel >= totalMaxMembers1BranchToRankUp[rank]){     //tổng thành viên tối đa của mỗi nhánh
            console.log("dieu kien3:",totalMaxMembers1BranchForUpdateLevel);
            return true;  
        }else{
            return false;
        }
        
    }
    function GetCodeRef() external onlySub view returns(bytes32) {
        return mSubInfo[msg.sender].codeRef;
    }



}