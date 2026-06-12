import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';
import { cloudinarySearchLoader } from './lib/cloudinary-search-loader';

const albums = defineCollection({
  loader: glob({ pattern: '**/*.yaml', base: './src/content/albums' }),
  schema: z.object({
    path: z.string(),
    title: z.string().optional(),
    description: z.string().optional(),
    cover: z.string().optional(),
    order: z.number().optional(),
    hidden: z.boolean().optional(),
    slug: z.string().optional(),
  }),
});

const photos = defineCollection({
  loader: cloudinarySearchLoader({
    folder: 'photo-portfolio',
    limit: 5000,
  }),
});

export const collections = { albums, photos };
