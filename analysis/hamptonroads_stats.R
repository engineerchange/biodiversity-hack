geo <- tribble(~fips,~place,~acre,~area,
               51073,"Gloucester County",142214.935,6194857787.303,
               51095,"James City County",95981.33,4180930041.992,
               51830,"City of Williamsburg",5779.756,251765449.683,
               51199,"York County",69138.482,3011659868.729,
               51181,"Surry County",180303.365,7853983170.533,
               51700,"City of Newport News",44930.639,1957170818.128,
               51650,"City of Hampton",33807.897,1472666088.882,
               51175,"Southampton County",385517.219,16793062879.823,
               51093,"Isle of Wight County",198886.821,8663475250.937,
               51620,"City of Franklin",5375.892,234172918.08,
               NA,"Town of Smithfield",6266.826,272981862.118,
               51800,"City of Suffolk",262330.844,11427085855.494,
               51550,"City of Chesapeake",224079.203,9760851056.775,
               51740,"City of Portsmouth",21511.983,937058229.462,
               51710,"City of Norfolk",35776.525,1558419184.338,
               51810,"City of Virginia Beach",165338.588,7202120104.16,
               51735,"City of Poquoson",10057.568,438105893.207
               )

geo %>%
  summarise(sqft=sum(area),acreage=sum(acre))

# 82210366460 sq ft
# 2948.9 sq mi ~ 3000 sq miles

# 1887298 acres ~ 1.9M sq acres

# state of virginia
# 2948.9/42774.2 ~ 6.894% ~ 7% of Virginia

