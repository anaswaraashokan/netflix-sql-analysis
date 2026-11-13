CREATE DATABASE netflix_db;
use netflix_db;
show tables;

# check missing
SELECT
  SUM(director = '' OR director IS NULL) AS missing_director,
  SUM(country  = '' OR country  IS NULL) AS missing_country,
  SUM(date_added = '' OR date_added IS NULL) AS missing_date
FROM netflix_titles;

# fill missing with unknown
UPDATE netflix_titles SET director = 'Unknown' WHERE director = '' OR director IS NULL;
UPDATE netflix_titles SET country  = 'Unknown' WHERE country  = '' OR country  IS NULL;


ALTER TABLE netflix_titles ADD COLUMN date_added_clean DATE;
UPDATE netflix_titles
SET date_added_clean = STR_TO_DATE(TRIM(date_added), '%M %d, %Y')
WHERE date_added <> '';

ALTER TABLE netflix_titles ADD COLUMN duration_value INT, ADD COLUMN duration_unit VARCHAR(20);
UPDATE netflix_titles
SET duration_value = CAST(SUBSTRING_INDEX(duration, ' ', 1) AS UNSIGNED),
    duration_unit  = SUBSTRING_INDEX(duration, ' ', -1)
WHERE duration <> '';

-- Check duplicates
SELECT title, COUNT(*) FROM netflix_titles GROUP BY title HAVING COUNT(*) > 1;

-- Select all columns from the netflix_titles table and display only the first 10 rows.
SELECT * FROM netflix_titles LIMIT 10;

-- Select the title and release year of the 5 most recently released titles. 
SELECT title, release_year FROM netflix_titles ORDER BY release_year DESC LIMIT 5;

-- Select the title and rating of all movies that are rated PG-13. 
select title,rating from netflix_titles where type='Movie' and rating='PG-13';

-- Select each content type (Movie / TV Show) and the total number of titles in each.
 select type,count(8) as total from netflix_titles group by type;
 
-- Select the average duration (in minutes) of all movies.
 select avg(duration_value) as avg_movie_mint from netflix_titles where type='Movie';
 
-- Select the earliest and latest release year in the dataset
select min(release_year),max(release_year) from netflix_titles;

-- Select each rating and the number of titles in it, sorted from highest to lowest
select rating,count(*) as total from netflix_titles group by rating order by total desc;

-- Select the directors who have more than 5 titles, excluding unknown directors
select director,count(*) as total from netflix_titles
where director !='Unknown'
group by director having total>2;

-- Select each year in which titles were added to Netflix and the number of titles added in that year.
select YEAR(date_added_clean) AS year_added, COUNT(*) AS total
FROM netflix_titles
WHERE date_added_clean IS NOT NULL
GROUP BY year_added
ORDER BY year_added;

CREATE TABLE title_genres (
  show_id VARCHAR(20),
  genre   VARCHAR(100)
);

INSERT INTO title_genres (show_id, genre)
WITH RECURSIVE split AS (
  SELECT show_id,
         TRIM(SUBSTRING_INDEX(listed_in, ',', 1)) AS genre,
         CASE WHEN LOCATE(',', listed_in) > 0
              THEN TRIM(SUBSTRING(listed_in, LOCATE(',', listed_in) + 1))
              ELSE NULL END AS rest
  FROM netflix_titles
  WHERE listed_in IS NOT NULL AND listed_in <> ''
  UNION ALL
  SELECT show_id,
         TRIM(SUBSTRING_INDEX(rest, ',', 1)),
         CASE WHEN LOCATE(',', rest) > 0
              THEN TRIM(SUBSTRING(rest, LOCATE(',', rest) + 1))
              ELSE NULL END
  FROM split
  WHERE rest IS NOT NULL
)
SELECT show_id, genre FROM split WHERE genre <> '';

-- Select each title along with its genres by joining netflix_titles and title_genres
select t.title ,g.genre from 
netflix_titles t inner join title_genres g on t.show_id=g.show_id;


CREATE TABLE title_countries (
  show_id VARCHAR(20),
  country VARCHAR(100)
);

INSERT INTO title_countries (show_id, country)
WITH RECURSIVE split AS (
  SELECT show_id,
         TRIM(SUBSTRING_INDEX(country, ',', 1)) AS country,
         CASE WHEN LOCATE(',', country) > 0
              THEN TRIM(SUBSTRING(country, LOCATE(',', country) + 1))
              ELSE NULL END AS rest
  FROM netflix_titles
  WHERE country IS NOT NULL AND country <> ''
  UNION ALL
  SELECT show_id,
         TRIM(SUBSTRING_INDEX(rest, ',', 1)),
         CASE WHEN LOCATE(',', rest) > 0
              THEN TRIM(SUBSTRING(rest, LOCATE(',', rest) + 1))
              ELSE NULL END
  FROM split
  WHERE rest IS NOT NULL
)
SELECT show_id, country FROM split WHERE country <> '';
select * from title_countries;


-- Select the top 10 countries with the highest number of titles.
select country ,count(*) as total from title_countries
group by country order by total desc limit 10;

-- Select the titles that have no country listed
SELECT t.title
FROM netflix_titles t
LEFT JOIN title_countries c on t.show_id=c.show_id
where c.show_id is null;

-- Select each genre and content type along with the number of titles in each combination
SELECT g.genre, t.type, COUNT(*) AS total
FROM title_genres g
JOIN netflix_titles t ON g.show_id = t.show_id
GROUP BY g.genre, t.type
ORDER BY total DESC; 

-- Select the movies whose duration is longer than the average movie duration
SELECT title, duration_value
FROM netflix_titles WHERE type = 'Movie' AND 
duration_value > (SELECT AVG(duration_value) FROM netflix_titles WHERE type = 'Movie');

-- Select the countries whose number of titles is above the average number of titles per country.
SELECT country, COUNT(*) AS total
FROM title_countries GROUP BY country
HAVING COUNT(*) > (SELECT AVG(cnt) FROM (SELECT COUNT(*) AS cnt FROM title_countries GROUP BY country) x);

-- Select each year added and its title count, and rank the years from most to least titles added.
SELECT YEAR(date_added_clean) AS year_added,
       COUNT(*) AS total,
       DENSE_RANK() OVER (ORDER BY COUNT(*) DESC) AS rnk
FROM netflix_titles
WHERE date_added_clean IS NOT NULL
GROUP BY year_added;

-- Create a stored procedure that selects the title, type, release year, and rating of all titles for a country passed as a parameter
DELIMITER //
CREATE PROCEDURE GetTitlesByCountry(IN country_name VARCHAR(100))
BEGIN
  SELECT t.title, t.type, t.release_year, t.rating
  FROM netflix_titles t
  JOIN title_countries c ON t.show_id = c.show_id
  WHERE c.country = country_name
  ORDER BY t.release_year DESC;
END //
DELIMITER ;

CALL GetTitlesByCountry('India');