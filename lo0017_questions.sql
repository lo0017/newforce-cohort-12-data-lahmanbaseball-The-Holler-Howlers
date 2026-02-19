----1. What range of years for baseball games played does the provided database cover?
SELECT MIN(year) AS first_year, MAX(year) AS last_year
FROM homegames;

----2. Find the name and height of the shortest player in the database. How many games did he play in? What is the name of the team for which he played?
SELECT CONCAT(namefirst, ' ', namelast) AS player_name, height, g_all AS total_appearances, name
FROM people
INNER JOIN appearances
USING(playerid)
INNER JOIN teams
USING(teamid, yearid)
WHERE height = (SELECT MIN(height) FROM people);

----3. Find all players in the database who played at Vanderbilt University. Create a list showing each player’s first and last names as well as the total salary they earned in the major leagues. Sort this list in descending order by the total salary earned. Which Vanderbilt player earned the most money in the majors?
WITH vandy_players AS(
	SELECT DISTINCT playerid, namefirst, namelast
	FROM collegeplaying
	INNER JOIN schools
	USING(schoolid)
	INNER JOIN people
	USING(playerid)
	WHERE schoolid LIKE 'vandy'
)

SELECT namefirst, namelast, SUM(salary)::NUMERIC::MONEY AS total_salary
FROM vandy_players
INNER JOIN salaries
USING(playerid)
GROUP BY namefirst, namelast
ORDER BY total_salary DESC;

----4. Using the fielding table, group players into three groups based on their position: label players with position OF as "Outfield", those with position "SS", "1B", "2B", and "3B" as "Infield", and those with position "P" or "C" as "Battery". Determine the number of putouts made by each of these three groups in 2016.
SELECT SUM(CASE WHEN pos IN ('P', 'C') THEN po END) AS Battery,
		SUM(CASE WHEN pos = 'OF' THEN po END) AS Outfield,
		SUM(CASE WHEN pos IN ('SS', '1B', '2B', '3B' ) THEN po END) AS Infield
FROM fielding
WHERE yearid = 2016;

----5. Find the average number of strikeouts per game by decade since 1920. Round the numbers you report to 2 decimal places. Do the same for home runs per game. Do you see any trends?
WITH decades AS(
	SELECT CONCAT((yearid / 10 * 10)::TEXT, '''s') AS decade, *
	FROM teams
	WHERE yearid >= 1920
)

SELECT decade, ROUND(SUM(hr)/SUM(g)::NUMERIC/2, 2) AS hr_per_game,
	ROUND(SUM(so)/SUM(g)::NUMERIC/2, 2) AS so_per_game
FROM decades
GROUP BY decade
ORDER BY decade;

----6. Find the player who had the most success stealing bases in 2016, where success is measured as the percentage of stolen base attempts which are successful. (A stolen base attempt results either in a stolen base or being caught stealing.) Consider only players who attempted at least 20 stolen bases.
SELECT namefirst, namelast, ROUND(SUM(sb)::NUMERIC/(SUM(sb) + SUM(cs)) * 100 ,2) AS sb_success_rate
FROM people
INNER JOIN batting
USING(playerid)
WHERE yearid = 2016
GROUP BY namefirst, namelast
HAVING SUM(sb) + SUM(cs) >= 20
ORDER BY sb_success_rate DESC;

----7. From 1970 – 2016, what is the largest number of wins for a team that did not win the world series? What is the smallest number of wins for a team that did win the world series? Doing this will probably result in an unusually small number of wins for a world series champion – determine why this is the case. Then redo your query, excluding the problem year. How often from 1970 – 2016 was it the case that a team with the most wins also won the world series? What percentage of the time?
SELECT MAX(w)
FROM teams
WHERE wswin = 'N' AND yearid BETWEEN 1970 AND 2016;

SELECT MIN(w)
FROM teams
WHERE wswin = 'Y' AND yearid BETWEEN 1970 AND 2016 AND yearid != 1981;

WITH most_wins AS(
	SELECT yearid, MAX(w) AS most_wins
	FROM teams
	WHERE yearid BETWEEN 1970 AND 2016 AND yearid != 1981 AND yearid != 1994
	GROUP BY yearid
)

SELECT SUM(CASE WHEN wswin = 'Y' THEN 1 END) AS total_ws_wins,
	ROUND(AVG(CASE WHEN wswin = 'Y' THEN 1 ELSE 0 END) * 100 , 2) AS win_pct 
FROM most_wins
INNER JOIN teams
USING(yearid)
WHERE w = most_wins;

----8. Using the attendance figures from the homegames table, find the teams and parks which had the top 5 average attendance per game in 2016 (where average attendance is defined as total attendance divided by number of games). Only consider parks where there were at least 10 games played. Report the park name, team name, and average attendance. Repeat for the lowest 5 average attendance.
(SELECT name, teams.park, homegames.attendance/games AS avg_attendance, 'Top 5' AS attendance_rank
FROM teams
INNER JOIN homegames
ON team = teamid AND year = yearid
WHERE yearid = 2016 AND games >= 10
ORDER BY avg_attendance DESC
LIMIT 5)
UNION
(SELECT name, teams.park, homegames.attendance/games AS avg_attendance, 'Bottom 5' AS attendance_rank
FROM teams
INNER JOIN homegames
ON team = teamid AND year = yearid
WHERE yearid = 2016 AND games >= 10
ORDER BY avg_attendance
LIMIT 5)
ORDER BY avg_attendance DESC;

----9. Which managers have won the TSN Manager of the Year award in both the National League (NL) and the American League (AL)? Give their full name and the teams that they were managing when they won the award.
SELECT
    p.namefirst,
    p.namelast,
    MAX(CASE WHEN a.lgid = 'NL' THEN m.teamid END) AS nl_team,
    MAX(CASE WHEN a.lgid = 'AL' THEN m.teamid END) AS al_team
FROM awardsmanagers a
JOIN people p
    ON a.playerid = p.playerid
JOIN managers m
    ON a.playerid = m.playerid
   AND a.yearid = m.yearid
   AND a.lgid = m.lgid
WHERE a.awardid ILIKE '%TSN Manager of the Year%'
GROUP BY p.playerid, p.namefirst, p.namelast
HAVING COUNT(DISTINCT a.lgid) = 2
ORDER BY p.namelast, p.namefirst;

----10. Find all players who hit their career highest number of home runs in 2016. Consider only players who have played in the league for at least 10 years, and who hit at least one home run in 2016. Report the players' first and last names and the number of home runs they hit in 2016.
WITH max_hr AS (
	SELECT playerid, MAX(hr) AS most_hr
	FROM batting
	GROUP BY playerid
)

SELECT namefirst, namelast, hr
FROM max_hr
INNER JOIN batting
USING(playerid)
INNER JOIN people
USING(playerid)
WHERE hr = most_hr AND batting.yearid = 2016 AND LEFT(debut, 4)::NUMERIC <= 2007 AND hr > 0
ORDER BY hr DESC;

----11. Is there any correlation between number of wins and team salary? Use data from 2000 and later to answer this question. As you do this analysis, keep in mind that salaries across the whole league tend to increase together, so you may want to look on a year-by-year basis. ----Struggled with this and 12.
WITH team_payroll AS (
    SELECT
        teamid,
        yearid,
        SUM(salary) AS total_salary
    FROM salaries
    WHERE yearid >= 2000
    GROUP BY teamid, yearid
)
SELECT
    t.yearid,
    t.teamid,
    t.w AS wins,
    tp.total_salary
FROM teams t
JOIN team_payroll tp
    ON t.teamid = tp.teamid
   AND t.yearid = tp.yearid
WHERE t.yearid >= 2000
ORDER BY t.yearid, t.w DESC;

WITH team_payroll AS (
    SELECT
        teamid,
        yearid,
        SUM(salary) AS total_salary
    FROM salaries
    WHERE yearid >= 2000
    GROUP BY teamid, yearid
),
team_data AS (
    SELECT
        t.yearid,
        t.w AS wins,
        tp.total_salary
    FROM teams t
    JOIN team_payroll tp
        ON t.teamid = tp.teamid
       AND t.yearid = tp.yearid
    WHERE t.yearid >= 2000
)
SELECT
    yearid,
    CORR(wins, total_salary) AS win_salary_correlation
FROM team_data
GROUP BY yearid
ORDER BY yearid;

---- 13. It is thought that since left-handed pitchers are more rare, causing batters to face them less often, that they are more effective. Investigate this claim and present evidence to either support or dispute this claim. First, determine just how rare left-handed pitchers are compared with right-handed pitchers. Are left-handed pitchers more likely to win the Cy Young Award? Are they more likely to make it into the hall of fame?
SELECT
    p.throws,
    COUNT(DISTINCT ph.playerID) AS num_pitchers
FROM pitching ph
JOIN people p
    ON ph.playerID = p.playerID
GROUP BY p.throws
ORDER BY num_pitchers DESC;----More right handed.

SELECT
    p.throws,
    COUNT(*) AS num_cy_young
FROM awardsplayers a
JOIN people p
    ON a.playerID = p.playerID
JOIN pitching ph
    ON ph.playerID = p.playerID
WHERE a.awardID ILIKE '%Cy Young%'
GROUP BY p.throws
ORDER BY num_cy_young DESC;----No

SELECT
    p.throws,
    COUNT(*) AS num_hof_pitchers
FROM halloffame h
JOIN people p
    ON h.playerID = p.playerID
JOIN pitching ph
    ON ph.playerID = p.playerID
WHERE h.inducted = 'Y'
GROUP BY p.throws
ORDER BY num_hof_pitchers DESC;----No

----**BONUS**----
----1. In these exercises, you'll explore a couple of other advanced features of PostgreSQL.In this question, you'll get to practice correlated subqueries and learn about the LATERAL keyword. Note: This could be done using window functions, but we'll do it in a different way in order to revisit correlated subqueries and see another keyword - LATERAL.
----a. First, write a query utilizing a correlated subquery to find the team with the most wins from each league in 2016.
SELECT l.lgid, t.teamid
FROM (
    SELECT DISTINCT lgid
    FROM teams
    WHERE yearid = 2016
) l
CROSS JOIN LATERAL (
    SELECT teamid
    FROM teams t
    WHERE t.yearid = 2016 
      AND t.lgid = l.lgid
    ORDER BY w DESC
    LIMIT 1
) t
ORDER BY l.lgid;

----b. One downside to using correlated subqueries is that you can only return exactly one row and one column. This means, for example that if we wanted to pull in not just the teamid but also the number of wins, we couldn't do so using just a single subquery. (Try it and see the error you get). Add another correlated subquery to your query on the previous part so that your result shows not just the teamid but also the number of wins by that team.
SELECT l.lgid, t.teamid, t.w AS wins
FROM (
    SELECT DISTINCT lgid
    FROM teams
    WHERE yearid = 2016
) l
CROSS JOIN LATERAL (
    SELECT teamid, w
    FROM teams t
    WHERE t.yearid = 2016
      AND t.lgid = l.lgid
    ORDER BY w DESC
    LIMIT 1
) t
ORDER BY l.lgid;

----c. If you are interested in pulling in the top (or bottom) values by group, you can also use the DISTINCT ON expression (https://www.postgresql.org/docs/9.5/sql-select.html#SQL-DISTINCT). Rewrite your previous query into one which uses DISTINCT ON to return the top team by league in terms of number of wins in 2016. Your query should return the league, the teamid, and the number of wins.
SELECT DISTINCT ON (t.lgid)
    t.lgid,
    t.teamid,
    t.w AS wins
FROM teams t
WHERE t.yearid = 2016
ORDER BY t.lgid, t.w DESC;

----d. If we want to pull in more than one column in our correlated subquery, another way to do it is to make use of the LATERAL keyword (https://www.postgresql.org/docs/9.4/queries-table-expressions.html#QUERIES-LATERAL). This allows you to write subqueries in FROM that make reference to columns from previous FROM items. This gives us the flexibility to pull in or calculate multiple columns or multiple rows (or both). Rewrite your previous query using the LATERAL keyword so that your result shows the teamid and number of wins for the team with the most wins from each league in 2016.
SELECT l.lgid, t.teamid, t.w AS wins
FROM (
    SELECT DISTINCT lgid
    FROM teams
    WHERE yearid = 2016
) AS l
CROSS JOIN LATERAL (
    SELECT teamid, w
    FROM teams t
    WHERE t.yearid = 2016
      AND t.lgid = l.lgid
    ORDER BY w DESC
    LIMIT 1
) AS t
ORDER BY l.lgid;

----e. Finally, another advantage of the LATERAL keyword over using correlated subqueries is that you return multiple result rows. (Try to return more than one row in your correlated subquery from above and see what type of error you get). Rewrite your query on the previous problem so that it returns the top 3 teams from each league in term of number of wins. Show the teamid and number of wins.
SELECT l.lgid, t.teamid, t.w AS wins
FROM (
    SELECT DISTINCT lgid
    FROM teams
    WHERE yearid = 2016
) AS l
CROSS JOIN LATERAL (
    SELECT teamid, w
    FROM teams t
    WHERE t.yearid = 2016
      AND t.lgid = l.lgid
    ORDER BY w DESC
    LIMIT 3
) AS t
ORDER BY l.lgid, t.w DESC;

----2. Another advantage of lateral joins is for when you create calculated columns. In a regular query, when you create a calculated column, you cannot refer it it when you create other calculated columns. This is particularly useful if you want to reuse a calculated column multiple times. For example, SELECT teamid, w, l, w + l AS total_games, w*100.0 / total_games AS winning_pct FROM teams WHERE yearid = 2016 ORDER BY winning_pct DESC; results in the error that "total_games" does not exist. However, I can restructure this query using the LATERAL keyword.
----a. Write a query which, for each player in the player table, assembles their birthyear, birthmonth, and birthday into a single column called birthdate which is of the date type.
SELECT 
    namefirst, namelast,
    MAKE_DATE(birthyear, birthmonth, birthday) AS birthdate
FROM people;

----b. Use your previous result inside a subquery using LATERAL to calculate for each player their age at debut and age at retirement. (Hint: It might be useful to check out the PostgreSQL date and time functions https://www.postgresql.org/docs/8.4/functions-datetime.html).
SELECT 
    p.namefirst,
    p.namelast,
    p.birthdate,
    EXTRACT(YEAR FROM age(p.debut, p.birthdate)) AS age_at_debut,
    EXTRACT(YEAR FROM age(p.finalgame, p.birthdate)) AS age_at_retirement
FROM LATERAL (
    SELECT 
        playerid,
        namefirst,
        namelast,
        MAKE_DATE(birthyear, birthmonth, birthday) AS birthdate,
        debut::date,
        finalgame::date
    FROM people
) AS p;

----c. Who is the youngest player to ever play in the major leagues?
SELECT 
    namefirst,
    namelast,
    debut::date AS debut_date,
    MAKE_DATE(birthyear, birthmonth, birthday) AS birthdate,
    EXTRACT(YEAR FROM age(debut::date, MAKE_DATE(birthyear, birthmonth, birthday))) 
        AS age_at_debut
FROM people
WHERE birthyear IS NOT NULL
  AND birthmonth IS NOT NULL
  AND birthday IS NOT NULL
  AND debut IS NOT NULL
ORDER BY age_at_debut ASC
LIMIT 1;

----d. Who is the oldest player to player in the major leagues? You'll likely have a lot of null values resulting in your age at retirement calculation. Check out the documentation on sorting rows here https://www.postgresql.org/docs/8.3/queries-order.html about how you can change how null values are sorted.
SELECT 
    namefirst,
    namelast,
    finalgame::date AS final_game_date,
    MAKE_DATE(birthyear, birthmonth, birthday) AS birthdate,
    EXTRACT(YEAR FROM age(finalgame::date, MAKE_DATE(birthyear, birthmonth, birthday))) AS age_at_retirement
FROM people
WHERE birthyear IS NOT NULL
  AND birthmonth IS NOT NULL
  AND birthday IS NOT NULL
  AND finalgame IS NOT NULL
ORDER BY age_at_retirement DESC NULLS LAST
LIMIT 1;

----3. For this question, you will want to make use of RECURSIVE CTEs (see https://www.postgresql.org/docs/13/queries-with.html). The RECURSIVE keyword allows a CTE to refer to its own output. Recursive CTEs are useful for navigating network datasets such as social networks, logistics networks, or employee hierarchies (who manages who and who manages that person). To see an example of the last item, see this tutorial: https://www.postgresqltutorial.com/postgresql-recursive-query/. In the next couple of weeks, you'll see how the graph database Neo4j can easily work with such datasets, but for now we'll see how the RECURSIVE keyword can pull it off (in a much less efficient manner) in PostgreSQL. (Hint: You might find it useful to look at this blog post when attempting to answer the following questions: https://data36.com/kevin-bacon-game-recursive-sql/.)
----a. Willie Mays holds the record of the most All Star Game starts with 18. How many players started in an All Star Game with Willie Mays? (A player started an All Star Game if they appear in the allstarfull table with a non-null startingpos value).
WITH mays_games AS (
    SELECT gameid
    FROM allstarfull
    WHERE playerid = 'mayswi01'
      AND startingpos IS NOT NULL
)
SELECT COUNT(DISTINCT playerid) AS num_players_with_mays
FROM allstarfull a
JOIN mays_games mg
  ON a.gameid = mg.gameid
WHERE a.startingpos IS NOT NULL
  AND a.playerid <> 'mayswi01';

----b. How many players didn't start in an All Star Game with Willie Mays but started an All Star Game with another player who started an All Star Game with Willie Mays? For example, Graig Nettles never started an All Star Game with Willie Mayes, but he did star the 1975 All Star Game with Blue Vida who started the 1971 All Star Game with Willie Mays.
WITH mays_teammates AS (
    SELECT DISTINCT a.playerid
    FROM allstarfull a
    JOIN allstarfull m
      ON a.gameid = m.gameid
    WHERE m.playerid = 'mayswi01'
      AND m.startingpos IS NOT NULL
      AND a.startingpos IS NOT NULL
      AND a.playerid <> 'mayswi01'
),
one_step_removed AS (
    SELECT DISTINCT a.playerid
    FROM allstarfull a
    JOIN allstarfull b
      ON a.gameid = b.gameid
    WHERE b.playerid IN (SELECT playerid FROM mays_teammates)
      AND b.startingpos IS NOT NULL
      AND a.startingpos IS NOT NULL
      AND a.playerid NOT IN (SELECT playerid FROM mays_teammates)
      AND a.playerid <> 'mayswi01'
)
SELECT COUNT(*) AS num_one_step_removed
FROM one_step_removed;

----c. We'll call two players connected if they both started in the same All Star Game. Using this, we can find chains of players. For example, one chain from Carlton Fisk to Willie Mays is as follows: Carlton Fisk started in the 1973 All Star Game with Rod Carew who started in the 1972 All Star Game with Willie Mays. Find a chain of All Star starters connecting Babe Ruth to Willie Mays.
WITH RECURSIVE player_chain AS (
    SELECT 
        playerid,
        playerid AS chain_start,
        ARRAY[playerid]::varchar[] AS path
    FROM allstarfull
    WHERE playerid = 'ruthba01'
      AND startingpos IS NOT NULL

    UNION ALL
    SELECT 
        a.playerid,
        pc.chain_start,
        path || a.playerid
    FROM allstarfull a
    JOIN allstarfull b
      ON a.gameid = b.gameid
    JOIN player_chain pc
      ON b.playerid = pc.playerid
    WHERE a.startingpos IS NOT NULL
      AND NOT a.playerid = ANY(pc.path)
)
SELECT *
FROM player_chain
WHERE playerid = 'mayswi01'
LIMIT 1;

----d. How large a chain do you need to connect Derek Jeter to Willie Mays?
WITH RECURSIVE player_chain AS (
    SELECT 
        playerid,
        ARRAY[playerid]::varchar[] AS path,
        0 AS depth
    FROM allstarfull
    WHERE playerid = 'jeterde01'
      AND startingpos IS NOT NULL

    UNION ALL
	
    SELECT 
        a.playerid,
        path || a.playerid,
        depth + 1
    FROM allstarfull a
    JOIN allstarfull b
      ON a.gameid = b.gameid
    JOIN player_chain pc
      ON b.playerid = pc.playerid
    WHERE a.startingpos IS NOT NULL
      AND NOT a.playerid = ANY(pc.path)
)
SELECT *
FROM player_chain
WHERE playerid = 'mayswi01'
ORDER BY depth ASC
LIMIT 1;