/**
 * MCP Server Selector Website
 * Interactive features and utilities
 */

// ===================================
// Smooth Scroll for Navigation Links
// ===================================

document.addEventListener('DOMContentLoaded', () => {
    // Handle smooth scrolling for anchor links
    const anchorLinks = document.querySelectorAll('a[href^="#"]');

    anchorLinks.forEach(link => {
        link.addEventListener('click', (e) => {
            const href = link.getAttribute('href');

            // Skip if it's just "#"
            if (href === '#') {
                e.preventDefault();
                return;
            }

            const targetId = href.substring(1);
            const targetElement = document.getElementById(targetId);

            if (targetElement) {
                e.preventDefault();

                // Get nav height for offset
                const nav = document.querySelector('.nav');
                const navHeight = nav ? nav.offsetHeight : 0;

                // Calculate position with offset
                const targetPosition = targetElement.offsetTop - navHeight - 20;

                // Smooth scroll to target
                window.scrollTo({
                    top: targetPosition,
                    behavior: 'smooth'
                });
            }
        });
    });
});

// ===================================
// Copy to Clipboard Functionality
// ===================================

document.addEventListener('DOMContentLoaded', () => {
    const copyButtons = document.querySelectorAll('.copy-btn');

    copyButtons.forEach(button => {
        button.addEventListener('click', async () => {
            const targetId = button.getAttribute('data-target');
            const targetElement = document.getElementById(targetId);

            if (!targetElement) {
                console.error('Target element not found:', targetId);
                return;
            }

            const textToCopy = targetElement.textContent;

            try {
                // Try using the modern Clipboard API
                if (navigator.clipboard && navigator.clipboard.writeText) {
                    await navigator.clipboard.writeText(textToCopy);
                } else {
                    // Fallback for older browsers
                    const textArea = document.createElement('textarea');
                    textArea.value = textToCopy;
                    textArea.style.position = 'fixed';
                    textArea.style.left = '-999999px';
                    document.body.appendChild(textArea);
                    textArea.select();
                    document.execCommand('copy');
                    document.body.removeChild(textArea);
                }

                // Update button state
                const originalText = button.textContent;
                button.textContent = 'Copied!';
                button.classList.add('copied');

                // Reset button after 2 seconds
                setTimeout(() => {
                    button.textContent = originalText;
                    button.classList.remove('copied');
                }, 2000);

            } catch (err) {
                console.error('Failed to copy text:', err);
                button.textContent = 'Error';
                setTimeout(() => {
                    button.textContent = 'Copy';
                }, 2000);
            }
        });
    });
});

// ===================================
// Scroll-based Nav Background
// ===================================

document.addEventListener('DOMContentLoaded', () => {
    const nav = document.querySelector('.nav');

    if (!nav) return;

    let lastScroll = 0;

    window.addEventListener('scroll', () => {
        const currentScroll = window.pageYOffset;

        // Add shadow when scrolled down
        if (currentScroll > 50) {
            nav.style.boxShadow = '0 4px 12px rgba(0, 0, 0, 0.3)';
        } else {
            nav.style.boxShadow = 'none';
        }

        lastScroll = currentScroll;
    });
});

// ===================================
// Intersection Observer for Animations
// ===================================

document.addEventListener('DOMContentLoaded', () => {
    // Only animate elements if user hasn't requested reduced motion
    const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    if (prefersReducedMotion) return;

    const observerOptions = {
        threshold: 0.1,
        rootMargin: '0px 0px -100px 0px'
    };

    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.style.opacity = '1';
                entry.target.style.transform = 'translateY(0)';
            }
        });
    }, observerOptions);

    // Observe cards and sections for fade-in animations
    const animatedElements = document.querySelectorAll(
        '.problem-card, .feature-card, .value-prop, .workflow-step'
    );

    animatedElements.forEach(el => {
        el.style.opacity = '0';
        el.style.transform = 'translateY(20px)';
        el.style.transition = 'opacity 0.6s ease, transform 0.6s ease';
        observer.observe(el);
    });
});

// ===================================
// Mobile Menu Toggle
// ===================================

document.addEventListener('DOMContentLoaded', () => {
    const navToggle = document.querySelector('.nav-toggle');
    const navMenu = document.querySelector('.nav-links');
    const navLinks = document.querySelectorAll('.nav-link');

    if (!navToggle || !navMenu) return;

    // Toggle mobile menu
    navToggle.addEventListener('click', () => {
        const isExpanded = navToggle.getAttribute('aria-expanded') === 'true';
        navToggle.setAttribute('aria-expanded', !isExpanded);
        navMenu.classList.toggle('active');

        // Prevent body scroll when menu is open
        document.body.style.overflow = navMenu.classList.contains('active') ? 'hidden' : '';
    });

    // Close mobile menu when clicking a link
    navLinks.forEach(link => {
        link.addEventListener('click', () => {
            navToggle.setAttribute('aria-expanded', 'false');
            navMenu.classList.remove('active');
            document.body.style.overflow = '';
        });
    });

    // Close mobile menu when clicking outside
    document.addEventListener('click', (e) => {
        if (!navToggle.contains(e.target) && !navMenu.contains(e.target)) {
            navToggle.setAttribute('aria-expanded', 'false');
            navMenu.classList.remove('active');
            document.body.style.overflow = '';
        }
    });

    // Close mobile menu on escape key
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && navMenu.classList.contains('active')) {
            navToggle.setAttribute('aria-expanded', 'false');
            navMenu.classList.remove('active');
            document.body.style.overflow = '';
            navToggle.focus(); // Return focus to toggle button
        }
    });
});

// ===================================
// Analytics Event Tracking (optional)
// ===================================

document.addEventListener('DOMContentLoaded', () => {
    // Track clicks on important CTAs
    const trackableElements = {
        'install-button': document.querySelectorAll('a[href="#install"]'),
        'github-button': document.querySelectorAll('a[href*="github.com"]'),
        'copy-install': document.querySelectorAll('.copy-btn')
    };

    Object.entries(trackableElements).forEach(([eventName, elements]) => {
        elements.forEach(element => {
            element.addEventListener('click', () => {
                // Placeholder for analytics tracking
                // Could integrate with Plausible, Simple Analytics, or similar
                if (typeof plausible !== 'undefined') {
                    plausible(eventName);
                }

                // Log to console for development
                console.log('Event tracked:', eventName);
            });
        });
    });
});

// ===================================
// Keyboard Navigation Enhancement
// ===================================

document.addEventListener('DOMContentLoaded', () => {
    // Add keyboard focus styles for accessibility
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Tab') {
            document.body.classList.add('keyboard-nav');
        }
    });

    document.addEventListener('mousedown', () => {
        document.body.classList.remove('keyboard-nav');
    });
});

// Add focus-visible styles dynamically
const style = document.createElement('style');
style.textContent = `
    .keyboard-nav *:focus {
        outline: 2px solid var(--color-primary);
        outline-offset: 2px;
    }
`;
document.head.appendChild(style);
