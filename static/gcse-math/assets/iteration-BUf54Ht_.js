const t="Iteration",e="Iteration Quiz",i=[{id:1,type:"iteration",text:"The number of rabbits in a field t days from now is Pᵗ where P₀ = 220 and Pᵗ₊₁ = 1.15(Pᵗ – 20). Work out the number of rabbits in the garden 3 days from now.",initialValue:220,formula:"1.15 * (P - 20)",iterations:3,answer:308.54375,explanation:`We start with 220 rabbits and apply the formula three times: 
1st day: 1.15(220 - 20) = 230 
2nd day: 1.15(230 - 20) = 241.5 
3rd day: 1.15(241.5 - 20) ≈ 308.54375`},{id:2,type:"iteration",text:"The number of people living in a town t years from now is Pᵗ where P₀ = 55000 and Pᵗ₊₁ = 1.03(Pᵗ – 800). Work out the number of people in the town 3 years from now.",initialValue:55e3,formula:"1.03 * (P - 800)",iterations:3,answer:57050.54,explanation:`We start with 55000 people and apply the formula three times: 
1st year: 1.03(55000 - 800) = 55806 
2nd year: 1.03(55806 - 800) = 56631.18 
3rd year: 1.03(56631.18 - 800) ≈ 57050.54`},{id:3,type:"iteration",text:"Using xₙ₊₁ = 3 + 9/xₙ² with x₀ = 3, find the values of x₁, x₂, and x₃.",initialValue:3,formula:"3 + 9 / (x ** 2)",iterations:3,answer:[6,3.75,4.64],explanation:`We apply the formula three times: 
x₁ = 3 + 9/3² = 6 
x₂ = 3 + 9/6² = 3.75 
x₃ = 3 + 9/3.75² ≈ 4.64`},{id:4,type:"iteration",text:"Using xₙ₊₁ = 5/(xₙ² + 3) with x₀ = 1, find the values of x₁, x₂, and x₃.",initialValue:1,formula:"5 / (x ** 2 + 3)",iterations:3,answer:[1.25,1.1858,1.2018],explanation:`We apply the formula three times: 
x₁ = 5/(1² + 3) = 1.25 
x₂ = 5/(1.25² + 3) ≈ 1.1858 
x₃ = 5/(1.1858² + 3) ≈ 1.2018`},{id:5,type:"iteration",text:"Starting with x₀ = 3, use the iteration formula xₙ₊₁ = (7/xₙ² + 2) three times to find an estimate for the solution to x³ – 2x² = 7.",initialValue:3,formula:"7 / (x ** 2) + 2",iterations:3,answer:[2.7778,2.9063,2.8309],explanation:`We apply the formula three times: 
x₁ = 7/3² + 2 ≈ 2.7778 
x₂ = 7/2.7778² + 2 ≈ 2.9063 
x₃ = 7/2.9063² + 2 ≈ 2.8309 
This final value is an estimate for the solution to x³ – 2x² = 7.`},{id:6,type:"iteration",text:"Starting with x₀ = 0, use the iteration formula xₙ₊₁ = (2 - x³)/(3) three times to find an estimate for the solution to x³ + 3x = 2.",initialValue:0,formula:"(2 - x ** 3) / 3",iterations:3,answer:[.6667,.7037,.7024],explanation:`We apply the formula three times: 
x₁ = (2 - 0³)/3 ≈ 0.6667 
x₂ = (2 - 0.6667³)/3 ≈ 0.7037 
x₃ = (2 - 0.7037³)/3 ≈ 0.7024 
This final value is an estimate for the solution to x³ + 3x = 2.`},{id:7,type:"iteration",text:"Using xₙ₊₁ = (5/(xₙ² + 2)) with x₀ = 2.5, find the values of x₁, x₂, and x₃. Then explain the relationship between these values and the equation x³ – 2x² – 5 = 0.",initialValue:2.5,formula:"5 / (x ** 2 + 2)",iterations:3,answer:[.7143,1.7241,1.1494],explanation:`We apply the formula three times: 
x₁ = 5/(2.5² + 2) ≈ 0.7143 
x₂ = 5/(0.7143² + 2) ≈ 1.7241 
x₃ = 5/(1.7241² + 2) ≈ 1.1494 
These values are converging towards a solution of the equation x³ – 2x² – 5 = 0. The iteration formula is derived from this equation, rearranged to x = (5/(x² + 2)).`}],a={topic:t,quizTitle:e,questions:i};export{a as default,i as questions,e as quizTitle,t as topic};
