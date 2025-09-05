#!/usr/bin/env python3
"""
Wardrobe Item Embedding Generation Script

This script generates and saves CLIP embeddings for all wardrobe items.
It should be run after adding new items to the wardrobe.
"""
import sys
import os
from pathlib import Path
from typing import Optional
import logging

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('embedding_generation.log')
    ]
)
logger = logging.getLogger(__name__)

# Add the project root to the Python path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(project_root)

def fix_image_path(image_path: Optional[str]) -> Optional[str]:
    """Ensure the image path points to the correct location in the filesystem."""
    if not image_path:
        return None
    
    # Convert to Path object for easier manipulation
    path = Path(image_path)
    
    # If path is already absolute, return as is
    if path.is_absolute():
        return str(path)
    
    # If path starts with /uploads/, try to find it in the uploads directory
    if image_path.startswith('/uploads/'):
        # Try with wardrobe subdirectory first
        possible_paths = [
            os.path.join(project_root, 'uploads', 'wardrobe', path.name),
            os.path.join(project_root, 'uploads', path.name),
            image_path  # Original path as fallback
        ]
    else:
        # For relative paths, assume they're relative to the uploads directory
        possible_paths = [
            os.path.join(project_root, 'uploads', 'wardrobe', image_path),
            os.path.join(project_root, 'uploads', image_path),
            image_path  # Original path as fallback
        ]
    
    # Return the first path that exists
    for p in possible_paths:
        if os.path.exists(p):
            return p
    
    return image_path  # Return original if no valid path found

def main():
    from app import create_app, db
    from app.models.models import WardrobeItem
    from app.services.embedding_generation import EmbeddingGenerator
    
    # Create Flask application context
    app = create_app()
    with app.app_context():
        # Initialize the embedding generator
        try:
            generator = EmbeddingGenerator()
            logger.info("✅ Successfully initialized embedding generator")
        except Exception as e:
            logger.error(f"❌ Failed to initialize embedding generator: {e}", exc_info=True)
            return 1
        
        # Get all wardrobe items
        items = WardrobeItem.query.all()
        total = len(items)
        logger.info(f"Found {total} wardrobe items to process")
        
        if total == 0:
            logger.warning("No wardrobe items found to process")
            return 0
        
        # Process each item
        success = 0
        for i, item in enumerate(items, 1):
            try:
                logger.info(f"Processing item {i}/{total} (ID: {item.item_id})...")
                
                # Fix the image path if needed
                original_path = item.image_path
                fixed_path = fix_image_path(original_path)
                
                if fixed_path != original_path:
                    logger.info(f"  Fixed image path: {original_path} -> {fixed_path}")
                    item.image_path = fixed_path
                
                # Generate and save embeddings
                if generator.generate_and_save_embeddings(item):
                    success += 1
                    logger.info(f"  Successfully processed item {item.item_id}")
                else:
                    logger.warning(f"  Failed to process item {item.item_id}")
                
            except Exception as e:
                logger.error(f"Error processing item {getattr(item, 'item_id', 'unknown')}: {e}", 
                            exc_info=True)
        
        # Print summary
        logger.info(f"\n✅ Completed! Successfully processed {success}/{total} items")
        if success < total:
            logger.warning(f"⚠️  Failed to process {total - success} items")
        
        return 0 if success == total else 1

if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:
        logger.critical(f"Unhandled exception: {e}", exc_info=True)
        sys.exit(1)
