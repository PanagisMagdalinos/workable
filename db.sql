CREATE TABLE `users_ratings_index` (
  `userId` bigint(20) NOT NULL,
  `tmdbId` double NOT NULL,
  `rating` double DEFAULT NULL,
  `year` bigint(20) DEFAULT NULL,
  `month` bigint(20) DEFAULT NULL,
  `day` bigint(20) DEFAULT NULL,
  `is_weekend` bigint(20) DEFAULT NULL,
  `timestamp` bigint(20) NOT NULL,
  PRIMARY KEY (`userId`,`tmdbId`,`timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `users_movies_tags_index` (
  `userId` bigint(20) NOT NULL,
  `tmdbId` double NOT NULL,
  `tag` varchar(200) NOT NULL,
  `year` bigint(20) DEFAULT NULL,
  `month` bigint(20) DEFAULT NULL,
  `day` bigint(20) DEFAULT NULL,
  `is_weekend` bigint(20) DEFAULT NULL,
  `timestamp` bigint(20) NOT NULL,
  PRIMARY KEY (`userId`,`tmdbId`,`tag`,`timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci

CREATE TABLE `users_genres_index` (
  `userId` bigint(20) NOT NULL,
  `tmdbId` double NOT NULL,
  `genre` varchar(100) NOT NULL,
  PRIMARY KEY (`userId`,`genre`,`tmdbId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;