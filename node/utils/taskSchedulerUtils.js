// utils/taskSchedulerUtils.js

function parseExtras(extras) {
    if (!extras) return {};
    try {
        return typeof extras === 'string' ? JSON.parse(extras) : extras;
    } catch (e) {
        console.error('Invalid extras JSON:', extras);
        return {};
    }
}


function formatTime(date) {
    return date.toTimeString().slice(0, 5);
}


function addHours(date, hours) {
    const newDate = new Date(date);
    newDate.setHours(newDate.getHours() + hours);
    return newDate;
}


function isTimeMatch(timeStr, now) {
    return timeStr === formatTime(now);
}

module.exports = { parseExtras, formatTime, addHours, isTimeMatch };