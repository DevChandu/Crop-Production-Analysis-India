/* Project queries */
-- 1.List the top 5 states contributing in crop production
select State_Name, sum(Production_in_tons) as total_production from crop_production
group by State_Name
order by total_production desc
limit 5;

-- 2. Analyze the impact of rainfall on average area cultivated
select rainfall, avg(Area_in_hectares) as avg_area_in_hectares from crop_production
group by rainfall
order by rainfall;

-- 3. Determine which crops yields the most in rainy regions
select Crop,avg(Yield_ton_per_hec) as avg_yield, avg(rainfall) as avg_rainfall from crop_production
where rainfall>(select avg(rainfall) from crop_production)
group by Crop
order by avg_yield desc;

-- 4. Find the top 3 crops in terms of production for each crop type
select Crop_Type,Crop,Production_in_tons, crop_rank
from(
	select Crop_Type,Crop,Production_in_tons, Rank() over(partition by Crop_Type order by Production_in_tons desc) as crop_rank 
	from crop_production
) as crop_prod
where crop_rank <=3;

-- 5. List states with the largest cultivated area but lowest production
select State_Name, sum(Area_in_hectares) as total_area, sum(Production_in_tons) as total_production from crop_production
group by State_Name
order by total_area desc, total_production;

-- 6. List the crops grown in states with average temperatures below 20°C
select distinct Crop from crop_production
where State_Name in (select distinct State_Name from crop_production
                   group by State_Name
                   having avg(temperature) <20); -- take long time to run and connection lost

select distinct State_Name from crop_production
                   group by State_Name
                   having avg(temperature) <20;
                   /* Out Put: arunachal pradesh,meghalaya,himachal pradesh,sikkim */
                   
select distinct Crop from crop_production
where State_Name in ('arunachal pradesh','meghalaya','himachal pradesh','sikkim');

-- 7. Rank crops based on their average area cultivated across states
select Crop,avg(Area_in_hectares) as avg_area, rank() over(order by avg(Area_in_hectares) desc) as crop_rank from crop_production
group by Crop;

-- 8. Compare the production of nitrogen-intensive crops vs potassium-intensive crops
select 
	case
		when N_nitrogen>K_potassium then 'Nitrogen Intensive'
		else 'Potassium Intensive'
	end as crop_intensive,
	sum(Production_in_tons) as total_production
from crop_production
group by crop_intensive;

-- 9. List the states with crop production exceeding 1 million tons
select State_Name, sum(Production_in_tons) as total_production from crop_production
group by State_Name
having total_production > 1000000
order by total_production desc;

-- 10. Compare the average rainfall required for different crop types
select Crop_Type, avg(rainfall) as avg_rainfall from crop_production
group by Crop_Type;

-- Time out error. Find crops with yields consistently above the state average.
select State_Name,Crop,Yield_ton_per_hec from crop_production c1
where Yield_ton_per_hec >( 
	select avg(Yield_ton_per_hec) from crop_production c2
    where c1.State_Name = c2.State_Name
    );

-- 11. Identify crops with production per hectare greater than the average production across all crops
select Crop,Yield_ton_per_hec from crop_production
where Yield_ton_per_hec > ( select avg(Yield_ton_per_hec) from crop_production );
	
    -- Same above query for state wise resuls
	select State_Name,Crop,sum(Yield_ton_per_hec) as total_yield from crop_production
	where Yield_ton_per_hec > ( select avg(Yield_ton_per_hec) from crop_production )
	group by State_Name,Crop;


-- 12. Identify the top crop with the highest yield in each state
select State_Name,Crop,Yield_ton_per_hec, state_rank
from (
	select State_Name, Crop, Yield_ton_per_hec,
           rank() over (partition by State_Name order by Yield_ton_per_hec desc) as state_rank
    from crop_production
) as stateRank
where state_rank <=1;

	-- Same above query for state and crop wise resuls
    select State_Name,Crop,sum(Yield_ton_per_hec) as total_yield, state_rank
	from (
		select State_Name, Crop, Yield_ton_per_hec,
			   rank() over (partition by State_Name order by Yield_ton_per_hec desc) as state_rank
		from crop_production
	) as stateRank
	where state_rank <=1
	group by State_Name,Crop;

-- 13. Find the crops that have both low nitrogen levels and high production levels
select State_Name,crop, min(N_nitrogen) as min_Nitrogen,max(Production_in_tons) as max_production 
from crop_production
where N_nitrogen < (select avg(N_nitrogen) from crop_production) and 
	  Production_in_tons > (select avg(Production_in_tons) from crop_production)
group by State_Name,Crop
order by min_Nitrogen, max_production;

-- 14. Retrieve the state and crop combinations with an average production higher than the overall average
select State_Name,Crop,avg(Production_in_tons) as avg_production from crop_production
group by State_Name,Crop
having avg(Production_in_tons) > (select avg(Production_in_tons) from crop_production);

-- 15. Find crops with yield differences across districts in the same state 			-- [Fetching data] --
select c1.State_Name, c1.District_Name, c1.Crop, abs(c1.Production / c1.Area - c2.Production / c2.Area) as yield_difference
from crop_yield c1
join crop_yield c2 on
					c1.State_Name = c2.State_Name and
                    c1.Crop = c2.Crop and
                    c1.District_Name != c2.District_Name;
                    
-- 16. Identify the top crops that contributed to at least 80% of total production in each state
with stateCropProduction as(
	select State_Name,Crop,sum(Production) as total_production, sum(sum(Production)) over (partition by State_Name) as state_total_production
    from crop_yield
    group by State_Name,Crop
),
cropRank as (
select State_Name, Crop, total_production, sum(total_production) over (partition by State_Name order by total_production desc) as cumulative_production,
state_total_production
from stateCropProduction
)
select State_Name, Crop, total_production from cropRank
where cumulative_production <= 0.8 * state_total_production;

-- 17. Compare the average nitrogen levels of crops grown in regions with high rainfall to those with low rainfall
select 
case
	when rainfall > (select avg(rainfall) from crop_production) then 'High Rainfall'
    else 'Low Rainfall'
end as region_rainfall,
avg(N_nitrogen) as avg_nitrogen
from crop_production
group by region_rainfall;

-- 18. List the top crop with year-over-year improvement in production for the maximum number of crops
with yoyImproved as(
select Crop,
	case when Production_2006_07 < Production_2007_08 then 1 else 0 end + 
    case when Production_2007_08 < Production_2008_09 then 1 else 0 end + 
    case when Production_2008_09 < Production_2009_10 then 1 else 0 end + 
    case when Production_2009_10 < Production_2010_11 then 1 else 0 end
    as yoy_improved
    from crop_production_year2006_to_2011
)
select * from yoyImproved
where yoy_improved = 4;

-- 19. Compare the yield per hectare from 2006-2011 against the most recent data
with historicalYield as(
	select Crop, avg(
					(Production_2006_07 / Area_2006_07) + 
					(Production_2007_08 / Area_2007_08) + 
					(Production_2008_09 / Area_2008_09) + 
					(Production_2009_10 / Area_2009_10) + 
					(Production_2010_11 / Area_201011)
				)/5 as avg_historical_yeild
	from crop_production_year2006_to_2011
    group by Crop
),
currentYield as(
	select Crop, avg(Production/Area) as avg_current_yeild
    from crop_yield
    group by Crop
)
select hy.Crop, hy.avg_historical_yeild, cy.avg_current_yeild, (cy.avg_current_yeild - hy.avg_historical_yeild) as yeild_differen
from historicalYield hy
join currentYield cy on hy.Crop = cy.Crop
order by yeild_differen desc;
