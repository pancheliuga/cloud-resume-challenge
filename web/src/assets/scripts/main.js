import 'focus-visible'

document.documentElement.classList.remove('no-js')

const API = process.env.API_URL

//Get Views
async function getViews() {
    try {
        let response = await fetch(API, {
            method: 'POST'
        })
        let data = await response.json()
        return data
    } catch (error) {
        console.log(error)
    }
}

// Render Views
async function renderViews() {
    const views = await getViews()
    if (views) {
        const viewsContainer = document.querySelector('#views')
        viewsContainer.innerHTML = views
    }
}

renderViews()

// Scroll State
const onScroll = () => {
    const scrollClassName = 'js-scrolled'
    const scrollTreshold = 200
    const isOverTreshold = window.scrollY > scrollTreshold

    if (isOverTreshold) {
        document.documentElement.classList.add(scrollClassName)
    } else {
        document.documentElement.classList.remove(scrollClassName)
    }
}
window.addEventListener('scroll', onScroll, { passive: true })

// Print Button
const printButton = document.querySelector('.js-print')
printButton.addEventListener('click', () => {
    window.print()
})
