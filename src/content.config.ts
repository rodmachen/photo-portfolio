import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';
import { cloudinarySearchLoader } from './lib/cloudinary-search-loader';

const childSchema = z.object({
  title: z.string(),
  slug: z.string(),
  description: z.string(),
  folder: z.string(),
  cover: z.string(),
  order: z.number(),
});

const albums = defineCollection({
  loader: glob({ pattern: '**/*.yaml', base: './src/content/albums' }),
  schema: z.object({
    title: z.string(),
    slug: z.string(),
    description: z.string(),
    folder: z.string().optional(),
    cover: z.string(),
    order: z.number(),
    children: z.array(childSchema).optional(),
  }),
});

const photos = defineCollection({
  loader: cloudinarySearchLoader({
    folder: 'photo-portfolio',
    limit: 500,
  }),
});

export const collections = { albums, photos };
