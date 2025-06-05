SELECT
    *
FROM
    title AS t
    LEFT JOIN (
        SELECT
            *
        FROM
            aka_title
        WHERE
            id < 2500
    ) AS at ON at.movie_id = t.id
    LEFT JOIN (
        SELECT
            *
        FROM
            movie_info
        WHERE
            id < 4000
    ) AS mi ON mi.movie_id = t.id
    LEFT JOIN (
        SELECT
            *
        FROM
            movie_info_idx
        WHERE
            id < 200000
    ) AS mii ON mii.movie_id = t.id
    LEFT JOIN (
        SELECT
            *
        FROM
            movie_keyword
        WHERE
            id < 40000
    ) AS mk ON mk.movie_id = t.id
    LEFT JOIN (
        SELECT
            *
        FROM
            movie_link
        WHERE
            id < 10000000
    ) AS ml ON ml.movie_id = t.id
    LEFT JOIN (
        SELECT
            *
        FROM
            movie_companies
        WHERE
            id < 50000
    ) AS mc ON mc.movie_id = t.id
    LEFT JOIN (
        SELECT
            *
        FROM
            complete_cast
        WHERE
            id < 50000
    ) AS cc ON cc.movie_id = t.id
    LEFT JOIN (
        SELECT
            *
        FROM
            cast_info
        WHERE
            id < 100000
    ) AS ci ON ci.movie_id = t.id
    LEFT JOIN (
        SELECT
            *
        FROM
            name
        WHERE
            id < 1000
    ) AS n ON n.id = ci.person_id
    LEFT JOIN (
        SELECT
            *
        FROM
            aka_name
        WHERE
            id < 10000
    ) AS an ON an.person_id = n.id
    LEFT JOIN (
        SELECT
            *
        FROM
            person_info
        WHERE
            id < 10000
    ) AS pi ON pi.person_id = n.id
    LEFT JOIN (
        SELECT
            *
        FROM
            char_name
        WHERE
            id < 1000
    ) AS cn ON cn.id = ci.role_id
    LEFT JOIN (
        SELECT
            *
        FROM
            company_name
        WHERE
            id < 5000
    ) AS cna ON cna.id = mc.company_id
    LEFT JOIN (
        SELECT
            *
        FROM
            keyword
        WHERE
            id < 1000
    ) AS k ON k.id = mk.keyword_id
WHERE
    t.id < 6000
ORDER BY
    t.id;
