
CPMM (xy=k) 방식의 AMM을 사용하는 DEX를 구현

- Swap
Pool 생성 시 지정된 두 종류의 토큰을 서로 교환 가능
수량이 0인 토큰으로 스왑
Input 토큰과 Input 수량, 최소 Output 요구량을 받아서 Output 토큰으로 바꿔주고,
최소 요구량에 미달할 경우 revert 해야함
수수료는 0.1%

    K=XY, fee:0.1%
    x=tokenXAmount, y=tokenYAmount
    X=_tokenX.balanceOf, Y=_tokenY.balanceOf

    ex) x->y swap
    XY=K=(X+x)(Y-y)
    XY-Xy+xY-xy=XY
    y(-X-x)=-xY
    y=xY/X+x
    y=((x*999/1000)*Y)/(X+(x*999/1000))
    
- Add / Remove Liquidity
ERC-20 기반 LP 토큰을 사용
수수료 수입과 Pool에 기부된 금액을 제외하고는 더 많은 토큰을 회수할 수 있는 취약점이 없어야 함
Concentrated Liquidity는 필요 없습니다.

- function swap(uint256 tokenXAmount, uint256 tokenYAmount, uint256 tokenMinimumOutputAmount) external returns (uint256 outputAmount);
tokenXAmount / tokenYAmount 중 하나는 무조건 0이어야 합니다. 수량이 0인 토큰으로 스왑됨.

- function addLiquidity(uint256 tokenXAmount, uint256 tokenYAmount, uint256 minimumLPTokenAmount) external returns (uint256 LPTokenAmount);
- function removeLiquidity(uint256 LPTokenAmount, uint256 minimumTokenXAmount, uint256 minimumTokenYAmount) external;
- function transfer(address to, uint256 lpAmount) external returns (bool);
