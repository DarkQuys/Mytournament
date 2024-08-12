pragma solidity ^0.8.9;
import "node_modules/@chainlink/contracts/src/v0.8/vrf/VRFConsumerBase.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./MatchTournament.sol" ;

//Tournament
contract TournamentLevelUp is VRFConsumerBase {
    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 public randomResult;
    MatchManagement public matchManagement;
    constructor() 
        VRFConsumerBase(
            0xAA77729D3466CA35AE8D28CEED6A09A9AAB0C56F153691C8AD1B38C1B7041B15, 
            0x514910771AF9Ca656af840dff83E8264EcF986CA  
        )
    {
        keyHash = 0xAA77729D3466CA35AE8D28CEED6A09A9AAB0C56F153691C8AD1B38C1B7041B15; // Example keyHash, replace with actual one
        fee = 0.1 * 10 ** 18; //phi cho link 
    }
    struct Tournament{
        string name ;
        uint startTime ;
        uint endTime ;
        uint entryFee ; 
        uint players  ;
        address winner;
        bool ended ; 
    }
    mapping(uint => Tournament) public tournaments ;
    uint public tournamentCount ;
    mapping(address => bool) public admins;
    mapping(address => bool) public referees;
    mapping(address => uint) public balances; 
    constructor() {
        admins[msg.sender] = true ;
    }
    modifier onlyAdmin() {
        require(admins[msg.sender], "Only admins can perform this action");
        _;
    }
    modifier onlyReferee (){
        require(referees[msg.sender] , "Not a referee");
        _;
    }
    function addAdmin( address adminn) external onlyAdmin{
        admins[adminn]= true ;
    }
    function removeAdmin(address adminn) external onlyAdmin{
        admins[adminn] =false ;

    }
    function addReferee(address referee) external onlyAdmin {
        referees[referee] = true;
    }
     function removeReferee(address referee) external onlyAdmin {
        referees[referee] = false;
    }
    event created(uint indexed id , string name , uint startTime , uint endTime ,uint entryFee ) ;
    event edited(uint indexed id , string name , uint startTime , uint endTime ,uint entryFee) ;
    event joined(uint indexed id) ;
    event setwin(uint indexed id , address winner  );
    function createTournament(string memory name, uint256 startTime, uint256 endTime, uint256 entryFee) external onlyAdmin {
        require(startTime < endTime, "Start time must be before end time");
        tournamentCount++;
        tournaments[tournamentCount] =Tournament({
            name: name,
            startTime: startTime,
            endTime: endTime,
            entryFee: entryFee,
            players : 0 ,
            winner: address(0),
            ended: false
        }
        );
        emit created(tournamentCount , name, startTime, endTime, entryFee);
    }
    function editTournament(uint256 id, string memory name, uint256 startTime, uint256 endTime, uint256 entryFee) external onlyAdmin {
        require(id > 0 && id <= tournamentCount, "Invalid tournament ID");
        require(startTime < endTime, "Start time must be before end time");
        tournaments[id].name = name;
        tournaments[id].startTime = startTime;
        tournaments[id].endTime = endTime;
        tournaments[id].entryFee = entryFee;
        emit edited(id , name, startTime, endTime, entryFee);
    }
    function joinTournament(uint256 id) external payable {
        require(id > 0 && id <= tournamentCount, "Invalid tournament ID");
        require(block.timestamp < tournaments[id].startTime, "Tournament has already started");
        require(msg.value == tournaments[id].entryFee, "Incorrect entry fee");
        tournaments[id].players++;
        balances[address(this)] += msg.value;
        emit joined(id);
    }
    function withdrawPrize() external {
        uint256 balance = balances[msg.sender];
        require(balance > 0, "No balance to withdraw");
        balances[msg.sender] = 0;
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "Transfer failed");
    }
    function setWinner(uint id , address winner) external onlyReferee(){
        require(id >0 && id < tournamentCount ,  "idex invalid");
        require(!tournaments[id].ended , "giai dau da ket thucs");
        tournaments[id].winner = winner ;
        balances[winner] = tournaments[id].entryFee * tournaments[id].players ;
        emit setwin(id, winner);
    }
    // Request a random number 
    function requestRandomNumber() public returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        return requestRandomness(keyHash, fee);
    }

    // Callback function used by Chainlink VRF to return the random number
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        randomResult = randomness;
    }
    function getRandomPosition(uint256 id) external view returns (uint256) {
        require(id > 0 && id <= tournamentCount, "Invalid tournament ID");
        require(block.timestamp >= tournaments[id].startTime, "Tournament has not started yet");
        require(randomResult > 0, "Random number not generated yet");
        return randomResult % tournaments[id].players;
    }
    
}

//MatchTournament
contract MatchTournament {
    struct MatchResult {
        address winner ;
        address loser ; 
        uint timestamp;
    }
    struct Tournament {
        uint id ;
        string name ; 
        MatchResult[] matchResults ;
    }

    mapping(uint => Tournament) public tournaments ;
    uint public TournamentCounts  ;

    event createdTournament (uint indexed id , string name ) ; 
    event recorded(uint indexed id , address winner , address loser) ; 

    function createTournament( string memory name ) external {
        TournamentCounts++ ;
        tournaments[TournamentCounts].id  =  TournamentCounts ; 
        tournaments[TournamentCounts].name = name ; 
        emit createdTournament(TournamentCounts, name);
    }
    function recordMatch( uint id ,address _winner ,  address _loser )external {
        require(id > 0 && id<= TournamentCounts , "ID invalid") ;
        require(_winner!=address(0) && _loser!=address(0) , " address invalid");
        require(_winner != _loser , "winner and loser can not same" ) ;
        MatchResult memory matchResult = MatchResult(_winner, _loser, block.timestamp);
        tournaments[id].matchResults.push(matchResult);
        emit recorded(id, _winner, _loser);
    }   

    function getRecordMatchTournament(uint idTournament)external view returns(MatchResult[] memory ){
        require(idTournament > 0 && idTournament<= TournamentCounts ,"ID invalid") ;
        return tournaments[idTournament].matchResults ;
    }
    function getTournament(uint id ) external view returns(Tournament memory){
        require(id>0 && id <=TournamentCounts ,"ID invalid");
        return tournaments[id] ; 
    }
}

//user manager 
contract UserManager is Ownable(msg.sender){
    struct User{
        string name  ;
        string email ; 
        string ipfsHash ;
    }
    mapping(address => User) private Users ;
    event registered(address indexed acc, string name , string email , string ipfsHash) ;
    event updated(address indexed acc , string name , string email , string ipfsHash ) ; 
    function registerUser(string memory name ,  string memory email ,string memory ipfsHash)public {
        require(bytes(Users[msg.sender].name).length ==0 ," User already rigisted" ) ;
        Users[msg.sender] = User(name , email , ipfsHash) ;
        emit registered(msg.sender, name, email, ipfsHash);
    }
    function updateUser(string memory name , string memory email , string memory ipfsHash)public {
        require(bytes(Users[msg.sender].name).length !=0 ,"User not register");
        Users[msg.sender] = User(name ,  email,  ipfsHash) ;
        emit updated(msg.sender, name , email,  ipfsHash);
    }
    function getUser(address userAddress) public view returns (string memory , string memory , string memory ){
        require( bytes(Users[msg.sender].name).length !=0 ,"user not register") ;
        return (User[msg.sender].name ,User[msg.sender].email , User[msg.sender].ipfsHash ) ;
    }
}

// NFT contract
contract NFTcontract is ERC721,Ownable() {
    uint private _tokenIds; 
    mapping(uint => string) private _tokenURIs ;
    constructor () ERC721 ("NTFManager" , "NTF"){} 

    function mint(address to , string memory tokenURI ) public onlyOwner returns(uint){
        _tokenIds++ ;
        _mint(to,_tokenIds);
        setTokenURI(_tokenIds , tokenURI) ;
        return _tokenIds ;
    }
    function setTokenURI(uint id , string memory tokenURI )internal{
        _tokenURIs[id] = tokenURI ;
    }
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);
    // function balanceOf(address _owner) external view returns (uint256);
    // function ownerOf(uint256 _tokenId) external view returns (address);
    // function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes data) external payable;
    // function safeTransferFrom(address _from, address _to, uint256 _tokenId) external payable;
    // function transferFrom(address _from, address _to, uint256 _tokenId) external payable;
    // function approve(address _approved, uint256 _tokenId) external payable;
    // function setApprovalForAll(address _operator, bool _approved) external;
    // function getApproved(uint256 _tokenId) external view returns (address);
    // function isApprovedForAll(address _owner, address _operator) external view returns (bool);
    mapping(address => uint ) internal _balances ;
    mapping(uint => address) internal _owners; 
    mapping(address=> mapping(address => bool)) private _operatorApprovals ;
    mapping(uint =>address) private _tokenApprovals; 
    // return number NTFs of user 
    function balanceOf(address _owner) external view returns (uint256){
        require(_owner != address(0) , "Address is zero");
        return  _balances[_owner] ;
    }
    // finds owner of an NTF
    function ownerOf(uint256 _tokenId) public view returns (address){
        address owner = _owners[_tokenId] ;
        require(owner != address(0) , "tokenId does not exist") ;
        return owner ;
    }
    function setApprovalForAll(address _operator, bool _approved) external {
        _operatorApprovals[msg.sender][_operator] =  _approved ;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }
    //check if address is operator for another address
    function isApprovedForAll(address _owner, address _operator) public view returns (bool){
        return _operatorApprovals[_owner][_operator] ;
    }
    //update an approved of NTF 
    function approve(address to , uint256 tokenId) public payable{
        address owner = ownerOf(tokenId) ; 
        require(msg.sender==owner || isApprovedForAll(owner , msg.sender) , "msg.sender is not a owner");
        _tokenApprovals[tokenId] = to ; 
        emit Approval(owner, to , tokenId);  
    }
    //get approved for NFT 
    function getApproved(uint256 tokenId) public view returns (address){
        require(_owners[tokenId] != address(0) ,"tokenId does not exist");
        return _tokenApprovals[tokenId] ;
    }
    //tranfer ownership of a single NTF
    function transferFrom(address from, address to, uint256 tokenId) public payable{
        address owner = ownerOf(tokenId); 
        require(msg.sender==owner || 
        getApproved(tokenId)==owner ||
        isApprovedForAll(msg.sender ,owner ), "msg.sender is not owner of NTF") ; 
        require(owner ==from , "address from is not a owner");
        require(to!= address(0), "address to is not zero address") ;
        require(_owners[tokenId] != address(0) , "addres is not exist");
        approve(address(0), tokenId);
        _balances[from]-=1 ;
        _balances[to] +=1; 
        _owners[tokenId] = to ;
        emit Transfer(from, to, tokenId);
    }
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) external payable{
        transferFrom(from, to, tokenId);
        require( _checkOnERC721Received(), "received is not implemented" );
    }
    function _checkOnERC721Received()internal pure returns(bool){
        return true ;
    }
    function safeTransferFrom(address from, address to, uint256 tokenId) external payable{
        transferFrom(from, to, tokenId);
    }

    function supportInterface(bytes4 interfaceID) public pure virtual returns(bool){
        return interfaceID = 0x80ac58cd ;
    } 
}